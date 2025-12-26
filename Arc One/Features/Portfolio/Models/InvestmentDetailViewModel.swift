//
//  InvestmentDetailViewModel.swift
//  Arc One
//
//  Created by Felipe Trejos on 26/12/25.
//

import UIKit

struct InvestmentDetailViewModel {
    let id: String
    let ticker: String
    let market: String
    let image: UIImage?
    
    let currentPriceText: String
    let dailyChangeText: String
    let dailyChangePositive: Bool
    
    let sinceBuyText: String
    let sinceBuyPositive: Bool
    
    let buyPositionText: String
    let quantityText: String
    let totalInvestedText: String
    let currentValueText: String
}
