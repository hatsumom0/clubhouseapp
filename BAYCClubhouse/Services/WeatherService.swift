import Foundation
import SwiftUI
import Combine

// MARK: - Weather Models

struct WeatherData: Codable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let description: String
    let icon: String
    let windSpeed: Double
    let cityName: String

    var temperatureFahrenheit: Int {
        Int(temperature)
    }

    var feelsLikeFahrenheit: Int {
        Int(feelsLike)
    }

    var windSpeedMph: Int {
        Int(windSpeed)
    }

    var sfSymbol: String {
        switch icon {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d": return "cloud.sun.rain.fill"
        case "10n": return "cloud.moon.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "snowflake"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }

    var gradientColors: [Color] {
        switch icon {
        case "01d": return [Color(hex: "f39c12"), Color(hex: "e74c3c")]
        case "01n": return [Color(hex: "2c3e50"), Color(hex: "1a1a2e")]
        case "02d", "03d", "04d": return [Color(hex: "74b9ff"), Color(hex: "0984e3")]
        case "02n", "03n", "04n": return [Color(hex: "636e72"), Color(hex: "2d3436")]
        case "09d", "09n", "10d", "10n": return [Color(hex: "74b9ff"), Color(hex: "636e72")]
        case "11d", "11n": return [Color(hex: "636e72"), Color(hex: "2d3436")]
        case "13d", "13n": return [Color(hex: "dfe6e9"), Color(hex: "b2bec3")]
        default: return [Color(hex: "74b9ff"), Color(hex: "0984e3")]
        }
    }

    var briefDescription: String {
        description.prefix(1).uppercased() + description.dropFirst()
    }
}

struct WeatherForecast: Identifiable {
    let id = UUID()
    let date: Date
    let high: Int
    let low: Int
    let icon: String
    let description: String

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var sfSymbol: String {
        switch icon {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d": return "cloud.sun.rain.fill"
        case "10n": return "cloud.moon.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "snowflake"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - OpenWeatherMap Response Models

private struct OpenWeatherResponse: Codable {
    let main: MainData
    let weather: [WeatherInfo]
    let wind: WindData
    let name: String

    struct MainData: Codable {
        let temp: Double
        let feels_like: Double
        let humidity: Int
    }

    struct WeatherInfo: Codable {
        let description: String
        let icon: String
    }

    struct WindData: Codable {
        let speed: Double
    }
}

private struct OpenWeatherForecastResponse: Codable {
    let list: [ForecastItem]

    struct ForecastItem: Codable {
        let dt: TimeInterval
        let main: MainData
        let weather: [WeatherInfo]

        struct MainData: Codable {
            let temp_min: Double
            let temp_max: Double
        }

        struct WeatherInfo: Codable {
            let description: String
            let icon: String
        }
    }
}

// MARK: - Weather Service

@MainActor
class WeatherService: ObservableObject {
    static let shared = WeatherService()

    // Thread-safe cached weather summary for non-MainActor contexts
    nonisolated(unsafe) private static var _cachedWeatherSummary: String = "Weather data is currently being loaded for Miami."
    nonisolated static var cachedWeatherSummary: String {
        get { _cachedWeatherSummary }
    }

    @Published var currentWeather: WeatherData?
    @Published var forecast: [WeatherForecast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let apiKey = Constants.API.openWeatherApiKey
    private let latitude = Constants.Location.miamiLatitude
    private let longitude = Constants.Location.miamiLongitude

    private init() {
        // Initialize with mock data for cached summary
        Task { @MainActor in
            Self._cachedWeatherSummary = self.getWeatherSummary()
        }
    }

    private func updateCachedSummary() {
        Self._cachedWeatherSummary = getWeatherSummary()
    }

    func fetchWeather() async {
        isLoading = true
        errorMessage = nil

        // For development, use mock data if no API key is set
        if apiKey == "YOUR_OPENWEATHER_API_KEY" {
            await MainActor.run {
                self.currentWeather = Self.mockWeather
                self.forecast = Self.mockForecast
                self.lastUpdated = Date()
                self.isLoading = false
                self.updateCachedSummary()
            }
            return
        }

        do {
            // Fetch current weather
            let currentURL = URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial")!
            let (currentData, _) = try await URLSession.shared.data(from: currentURL)
            let currentResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: currentData)

            await MainActor.run {
                self.currentWeather = WeatherData(
                    temperature: currentResponse.main.temp,
                    feelsLike: currentResponse.main.feels_like,
                    humidity: currentResponse.main.humidity,
                    description: currentResponse.weather.first?.description ?? "Unknown",
                    icon: currentResponse.weather.first?.icon ?? "01d",
                    windSpeed: currentResponse.wind.speed,
                    cityName: currentResponse.name
                )
                self.lastUpdated = Date()
            }

            // Fetch 5-day forecast
            let forecastURL = URL(string: "https://api.openweathermap.org/data/2.5/forecast?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial")!
            let (forecastData, _) = try await URLSession.shared.data(from: forecastURL)
            let forecastResponse = try JSONDecoder().decode(OpenWeatherForecastResponse.self, from: forecastData)

            // Group forecast by day and get daily highs/lows
            var dailyForecasts: [String: (high: Double, low: Double, icon: String, description: String, date: Date)] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for item in forecastResponse.list {
                let date = Date(timeIntervalSince1970: item.dt)
                let dayKey = dateFormatter.string(from: date)

                if let existing = dailyForecasts[dayKey] {
                    dailyForecasts[dayKey] = (
                        high: max(existing.high, item.main.temp_max),
                        low: min(existing.low, item.main.temp_min),
                        icon: existing.icon,
                        description: existing.description,
                        date: existing.date
                    )
                } else {
                    dailyForecasts[dayKey] = (
                        high: item.main.temp_max,
                        low: item.main.temp_min,
                        icon: item.weather.first?.icon ?? "01d",
                        description: item.weather.first?.description ?? "Unknown",
                        date: date
                    )
                }
            }

            let sortedForecasts = dailyForecasts.sorted { $0.value.date < $1.value.date }
            await MainActor.run {
                self.forecast = sortedForecasts.prefix(5).map { (_, value) in
                    WeatherForecast(
                        date: value.date,
                        high: Int(value.high),
                        low: Int(value.low),
                        icon: value.icon,
                        description: value.description
                    )
                }
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Unable to fetch weather data"
                // Fall back to mock data
                self.currentWeather = Self.mockWeather
                self.forecast = Self.mockForecast
                self.lastUpdated = Date()
            }
        }

        await MainActor.run {
            self.isLoading = false
            self.updateCachedSummary()
        }
    }

    // MARK: - Weather Summary for AI Concierge

    func getWeatherSummary() -> String {
        guard let weather = currentWeather else {
            return "Weather data is currently unavailable for Miami."
        }

        var summary = "Current weather at the BAYC Miami Clubhouse: \(weather.temperatureFahrenheit)°F"

        if weather.feelsLikeFahrenheit != weather.temperatureFahrenheit {
            summary += " (feels like \(weather.feelsLikeFahrenheit)°F)"
        }

        summary += ". \(weather.briefDescription)"
        summary += ". Humidity: \(weather.humidity)%"
        summary += ". Wind: \(weather.windSpeedMph) mph."

        // Add activity suggestions based on weather
        if weather.temperature >= 75 && weather.temperature <= 85 {
            summary += " Perfect weather for the rooftop lounge!"
        } else if weather.temperature > 85 {
            summary += " It's hot out there - the pool area is a great choice today."
        } else if weather.icon.contains("10") || weather.icon.contains("09") {
            summary += " Rain expected - indoor events are recommended."
        }

        if !forecast.isEmpty {
            summary += "\n\nUpcoming forecast:"
            for day in forecast.prefix(3) {
                summary += "\n• \(day.dayName): High \(day.high)°F, Low \(day.low)°F - \(day.description)"
            }
        }

        return summary
    }

    func suggestEventsForWeather() -> [String] {
        guard let weather = currentWeather else { return [] }

        var suggestions: [String] = []

        if weather.icon.contains("01") || weather.icon.contains("02") {
            // Clear or partly cloudy
            suggestions.append("Rooftop Sunset Lounge")
            suggestions.append("Pool Day Party")
            suggestions.append("Yacht Excursion")
        }

        if weather.icon.contains("10") || weather.icon.contains("09") || weather.icon.contains("11") {
            // Rainy or stormy
            suggestions.append("Members-Only Art Gallery")
            suggestions.append("Indoor Cigar Lounge")
            suggestions.append("Private Dining Experience")
        }

        if weather.temperature >= 75 {
            suggestions.append("Beach Club Access")
        }

        return suggestions
    }

    // MARK: - Mock Data

    static let mockWeather = WeatherData(
        temperature: 82,
        feelsLike: 86,
        humidity: 65,
        description: "partly cloudy",
        icon: "02d",
        windSpeed: 12,
        cityName: "Miami Beach"
    )

    static let mockForecast: [WeatherForecast] = [
        WeatherForecast(date: Date(), high: 84, low: 75, icon: "02d", description: "Partly Cloudy"),
        WeatherForecast(date: Date().addingTimeInterval(86400), high: 86, low: 76, icon: "01d", description: "Sunny"),
        WeatherForecast(date: Date().addingTimeInterval(172800), high: 83, low: 74, icon: "10d", description: "Scattered Showers"),
        WeatherForecast(date: Date().addingTimeInterval(259200), high: 81, low: 73, icon: "02d", description: "Partly Cloudy"),
        WeatherForecast(date: Date().addingTimeInterval(345600), high: 85, low: 75, icon: "01d", description: "Sunny")
    ]
}
