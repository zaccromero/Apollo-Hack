import SwiftUI

struct ApolloInstrumentTermsView: View {
    let asset: ApolloAsset
    var body: some View {
        ApolloPanel { VStack(alignment: .leading, spacing: 12) {
            if let stable = asset.stablecoin {
                ApolloEyebrow(text: "DEMO stablecoin · not cash")
                Text("Target peg: \(stable.targetPeg.apolloQuantity) \(stable.pegCurrency)").font(.headline)
                Text("A target is not a guarantee. Depeg, reserve, issuer and custody risks can cause loss. Redemption is not guaranteed; this token remains a portfolio holding, separate from virtual cash.").font(.subheadline).foregroundStyle(ApolloStyle.amber)
            }
            if let bond = asset.bond {
                ApolloEyebrow(text: "Fictional direct bond · DEMO terms")
                Text("\(bond.faceValue.apolloMoney) face · \((bond.annualCouponRate.apolloDouble * 100).formatted())% annual coupon · \(bond.couponFrequency) payments/year").font(.headline)
                Text("Maturity: \(bond.maturesAt)").font(.caption)
                Text("Clean quote \(bond.cleanPricePer100.apolloQuantity) per $100 face + \(bond.accruedInterestPerBond.apolloMoney) accrued = \(bond.dirtyPrice.apolloMoney) per whole bond.").font(.subheadline)
                Text("Contractual annual coupon: \(bond.annualCoupon.apolloMoney). Coupon payments and maturity settlement are not simulated. Credit default, rates and liquidity can cause loss.").font(.caption).foregroundStyle(ApolloStyle.amber)
                if bond.isMatured { Text("Matured · unsettled demo snapshot. No new paper trades.").font(.caption.bold()).foregroundStyle(ApolloStyle.amber) }
            }
        } }.accessibilityIdentifier("instrument-terms")
    }
}
