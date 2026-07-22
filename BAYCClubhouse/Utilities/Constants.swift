import Foundation

enum Constants {
    // MARK: - API Keys
    // TODO: Move these to secure storage / environment variables
    enum API {
        static let privyAppId = "YOUR_PRIVY_APP_ID"
        static let alchemyApiKey = "YOUR_ALCHEMY_API_KEY"
        static let openWeatherApiKey = "YOUR_OPENWEATHER_API_KEY"
    }

    // MARK: - Location
    enum Location {
        static let miamiLatitude = 25.7617
        static let miamiLongitude = -80.1918
        static let clubhouseAddress = "1234 Ocean Drive, Miami Beach, FL 33139"
    }

    // MARK: - Contract Addresses (Ethereum Mainnet)
    enum Contracts {
        static let bayc = "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
        static let mayc = "0x60E4d786628Fea6478F785A6d7e704777c86a7c6"
    }

    // MARK: - URLs
    enum URLs {
        static let alchemyBaseURL = "https://eth-mainnet.g.alchemy.com/nft/v3"
        static let privyAuthURL = "https://auth.privy.io"
    }

    // MARK: - Glyph sign-in (real @use-glyph/sdk-react via web bridge)
    enum Glyph {
        /// Where the glyph-auth-bridge web app is served.
        /// DEBUG: `npm run dev` in glyph-auth-bridge/ (simulator reaches the Mac's localhost).
        /// RELEASE: the hosted bridge (Cloudflare Pages) — update once the site exists.
        #if DEBUG
        static let bridgeURL = "http://localhost:5173"
        #else
        static let bridgeURL = "https://REPLACE-WITH-YOUR-CLOUDFLARE-DOMAIN.pages.dev"
        #endif
        static let callbackScheme = "baycclubhouse"
        static let callbackURL = "baycclubhouse://glyph-auth"
    }

    // MARK: - App Config
    enum App {
        static let bundleId = "com.yuga.bayc-clubhouse"
        static let appName = "BAYC Miami Clubhouse"
        static let minimumIOSVersion = "17.0"
    }

    // MARK: - Brand Colors
    enum Colors {
        static let primaryOrange = "f39c12"
        static let secondaryRed = "e74c3c"
        static let backgroundDark = "1a1a2e"
        static let backgroundMid = "16213e"
        static let backgroundLight = "0f3460"
        static let glyphPurple = "8b5cf6"
    }

    // MARK: - Membership
    enum Membership {
        static let signatureMessage = "Sign this message to verify your BAYC membership for the Miami Clubhouse."
        static let qrCodeExpirationSeconds: TimeInterval = 300 // 5 minutes
    }
}
