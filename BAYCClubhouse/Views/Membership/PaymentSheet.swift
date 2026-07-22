import SwiftUI
import PassKit

// MARK: - Payment Sheet

struct PaymentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let amount: Double
    let itemDescription: String
    let onPay: (PaymentMethod, Double) -> Void

    @State private var selectedPaymentMethod: PaymentMethod = .applePay
    @State private var selectedTipPercent: Double = 18
    @State private var customTipAmount: String = ""
    @State private var showingCustomTip = false
    @State private var isProcessing = false
    @State private var paymentSuccess = false
    @State private var showingGlyphWallet = false
    @State private var selectedCurrency: GlyphCurrency?

    private let tipOptions: [Double] = [15, 18, 20, 25]

    // Simulated wallet currencies (would come from actual Glyph wallet SDK)
    private let walletCurrencies: [GlyphCurrency] = [
        GlyphCurrency(symbol: "ETH", name: "Ethereum", balance: 2.45, usdValue: 7842.50, icon: "eth.circle.fill"),
        GlyphCurrency(symbol: "APE", name: "ApeCoin", balance: 1250.0, usdValue: 3125.00, icon: "dollarsign.circle.fill"),
        GlyphCurrency(symbol: "USDC", name: "USD Coin", balance: 523.45, usdValue: 523.45, icon: "dollarsign.circle.fill"),
        GlyphCurrency(symbol: "WETH", name: "Wrapped ETH", balance: 0.5, usdValue: 1600.00, icon: "w.circle.fill")
    ]

    var tipAmount: Double {
        if showingCustomTip, let custom = Double(customTipAmount) {
            return custom
        }
        return amount * (selectedTipPercent / 100)
    }

    var totalAmount: Double {
        amount + tipAmount
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()

                if paymentSuccess {
                    paymentSuccessView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Amount Display
                            amountSection

                            // Tip Selection
                            tipSection

                            // Payment Methods
                            paymentMethodsSection

                            // Total
                            totalSection

                            // Pay Button
                            payButton

                            Spacer().frame(height: 40)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingGlyphWallet) {
            GlyphWalletSheet(
                amount: totalAmount,
                currencies: walletCurrencies,
                onSelect: { currency in
                    selectedCurrency = currency
                    showingGlyphWallet = false
                    processGlyphPayment(with: currency)
                }
            )
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: 8) {
            Text("Subtotal")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.72))

            Text("$\(String(format: "%.2f", amount))")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(itemDescription)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
        }
        .padding(.vertical, 20)
    }

    // MARK: - Tip Section

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a Tip")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.78))

            // Tip percentage options
            HStack(spacing: 10) {
                ForEach(tipOptions, id: \.self) { percent in
                    TipButton(
                        percent: percent,
                        amount: amount * (percent / 100),
                        isSelected: !showingCustomTip && selectedTipPercent == percent
                    ) {
                        showingCustomTip = false
                        selectedTipPercent = percent
                    }
                }

                // Custom tip button
                Button {
                    showingCustomTip = true
                } label: {
                    VStack(spacing: 4) {
                        Text("Custom")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        Text("$---")
                            .font(.system(size: 12, design: .rounded))
                            .opacity(0.7)
                    }
                    .foregroundColor(showingCustomTip ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(showingCustomTip ? Color(hex: "f39c12") : .white.opacity(0.1))
                    )
                }
            }

            // Custom tip input
            if showingCustomTip {
                HStack {
                    Text("$")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    TextField("0.00", text: $customTipAmount)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Payment Methods Section

    private var paymentMethodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Method")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.78))

            ForEach(PaymentMethod.allCases, id: \.self) { method in
                PaymentMethodRow(
                    method: method,
                    isSelected: selectedPaymentMethod == method
                ) {
                    selectedPaymentMethod = method
                }
            }
        }
    }

    // MARK: - Total Section

    private var totalSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                Spacer()
                Text("$\(String(format: "%.2f", amount))")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white)
            }

            HStack {
                Text("Tip")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                Spacer()
                Text("$\(String(format: "%.2f", tipAmount))")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            HStack {
                Text("Total")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("$\(String(format: "%.2f", totalAmount))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "f39c12"))
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Pay Button

    private var payButton: some View {
        Button {
            processPayment()
        } label: {
            HStack(spacing: 10) {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: selectedPaymentMethod.icon)
                        .font(.system(size: 18))

                    Text("Pay $\(String(format: "%.2f", totalAmount))")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Group {
                    if selectedPaymentMethod == .applePay {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "f39c12"), Color(hex: "e67e22")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            )
        }
        .disabled(isProcessing)
    }

    // MARK: - Payment Success View

    private var paymentSuccessView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }

            VStack(spacing: 8) {
                Text("Payment Successful!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("$\(String(format: "%.2f", totalAmount)) paid via \(selectedPaymentMethod.rawValue)")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func processPayment() {
        switch selectedPaymentMethod {
        case .applePay:
            processApplePay()
        case .glyphWallet:
            showingGlyphWallet = true
        case .billToMembership:
            processStandardPayment()
        }
    }

    private func processApplePay() {
        // Check if Apple Pay is available
        guard PKPaymentAuthorizationController.canMakePayments() else {
            // Fall back to standard processing if Apple Pay not available
            processStandardPayment()
            return
        }

        // Create payment request
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.yuga.baycclubhouse"
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.supportedCountries = ["US"]
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "US"
        request.currencyCode = "USD"

        // Create payment summary items
        var paymentItems: [PKPaymentSummaryItem] = []
        paymentItems.append(PKPaymentSummaryItem(label: itemDescription, amount: NSDecimalNumber(value: amount)))

        if tipAmount > 0 {
            paymentItems.append(PKPaymentSummaryItem(label: "Tip", amount: NSDecimalNumber(value: tipAmount)))
        }

        paymentItems.append(PKPaymentSummaryItem(label: "BAYC Miami Clubhouse", amount: NSDecimalNumber(value: totalAmount)))
        request.paymentSummaryItems = paymentItems

        // Present Apple Pay
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = ApplePayDelegate.shared
        ApplePayDelegate.shared.onComplete = { success in
            if success {
                withAnimation(.spring(response: 0.5)) {
                    self.paymentSuccess = true
                }
                self.onPay(self.selectedPaymentMethod, self.showingCustomTip ? 0 : self.selectedTipPercent)
            }
        }
        controller.present { presented in
            if !presented {
                // Fallback if couldn't present
                self.processStandardPayment()
            }
        }
    }

    private func processGlyphPayment(with currency: GlyphCurrency) {
        isProcessing = true

        // Simulate blockchain transaction
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isProcessing = false

            withAnimation(.spring(response: 0.5)) {
                paymentSuccess = true
            }

            // Callback
            onPay(selectedPaymentMethod, showingCustomTip ? 0 : selectedTipPercent)
        }
    }

    private func processStandardPayment() {
        isProcessing = true

        // Simulate payment processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isProcessing = false

            withAnimation(.spring(response: 0.5)) {
                paymentSuccess = true
            }

            // Callback
            onPay(selectedPaymentMethod, showingCustomTip ? 0 : selectedTipPercent)
        }
    }
}

// MARK: - Tip Button

struct TipButton: View {
    let percent: Double
    let amount: Double
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(Int(percent))%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Text("$\(String(format: "%.2f", amount))")
                    .font(.system(size: 12, design: .rounded))
                    .opacity(0.7)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "f39c12") : .white.opacity(0.1))
            )
        }
    }
}

// MARK: - Payment Method Row

struct PaymentMethodRow: View {
    let method: PaymentMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(methodColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: method.icon)
                        .font(.system(size: 20))
                        .foregroundColor(methodColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(method.description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "f39c12"))
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color(hex: "f39c12").opacity(0.15) : .white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color(hex: "f39c12").opacity(0.5) : .clear, lineWidth: 1)
                    )
            )
        }
    }

    private var methodColor: Color {
        switch method {
        case .applePay: return .white
        case .billToMembership: return Color(hex: "3498db")
        case .glyphWallet: return Color(hex: "9b59b6")
        }
    }
}

// MARK: - Glyph Currency Model

struct GlyphCurrency: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let balance: Double
    let usdValue: Double
    let icon: String

    var formattedBalance: String {
        if balance >= 1000 {
            return String(format: "%.2f", balance)
        } else if balance >= 1 {
            return String(format: "%.4f", balance)
        } else {
            return String(format: "%.6f", balance)
        }
    }

    var formattedUsdValue: String {
        String(format: "$%.2f", usdValue)
    }
}

// MARK: - Glyph Wallet Sheet

struct GlyphWalletSheet: View {
    @Environment(\.dismiss) private var dismiss

    let amount: Double
    let currencies: [GlyphCurrency]
    let onSelect: (GlyphCurrency) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "9b59b6"))

                        Text("Select Currency")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Amount due: $\(String(format: "%.2f", amount))")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))
                    }
                    .padding(.top, 20)

                    // Currency list
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(currencies) { currency in
                                CurrencyRow(currency: currency, amountDue: amount) {
                                    onSelect(currency)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Glyph Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Currency Row

struct CurrencyRow: View {
    let currency: GlyphCurrency
    let amountDue: Double
    let onSelect: () -> Void

    private var hasSufficientFunds: Bool {
        currency.usdValue >= amountDue
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Currency icon
                ZStack {
                    Circle()
                        .fill(currencyColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Text(currency.symbol.prefix(1))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(currencyColor)
                }

                // Currency info
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(currency.formattedBalance) \(currency.symbol)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                }

                Spacer()

                // USD value
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currency.formattedUsdValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    if hasSufficientFunds {
                        Text("Sufficient")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.green)
                    } else {
                        Text("Insufficient")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(hasSufficientFunds ? Color.white.opacity(0.08) : Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(hasSufficientFunds ? Color.clear : Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .disabled(!hasSufficientFunds)
        .opacity(hasSufficientFunds ? 1.0 : 0.6)
    }

    private var currencyColor: Color {
        switch currency.symbol {
        case "ETH", "WETH": return Color(hex: "627eea")
        case "APE": return Color(hex: "0047ab")
        case "USDC": return Color(hex: "2775ca")
        default: return Color(hex: "9b59b6")
        }
    }
}

// MARK: - Apple Pay Delegate

class ApplePayDelegate: NSObject, PKPaymentAuthorizationControllerDelegate {
    static let shared = ApplePayDelegate()

    var onComplete: ((Bool) -> Void)?

    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // In production, you would process the payment token here
        // payment.token contains the encrypted payment data

        // Simulate successful authorization
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            // Payment completed (either success or cancelled)
            self.onComplete?(true)
        }
    }
}

#Preview {
    PaymentSheet(
        amount: 47.50,
        itemDescription: "3 items",
        onPay: { _, _ in }
    )
}
