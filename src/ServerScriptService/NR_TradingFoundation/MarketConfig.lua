local MarketConfig = {}
MarketConfig.Enabled = false -- Never activate before full settlement and recovery integration
MarketConfig.MinPriceMultiplier = 1
MarketConfig.MaxPriceMultiplier = 100
MarketConfig.ListingSeconds = 300
MarketConfig.AuctionSeconds = 300
MarketConfig.AuctionMaximumSeconds = 420
MarketConfig.AuctionExtensionSeconds = 15
MarketConfig.ListingFeePercent = 5
MarketConfig.AuctionFeePercent = 10
MarketConfig.StandardLimit = 5
MarketConfig.VipLimit = 7
MarketConfig.TradeMaximumItemsPerSide = 5
MarketConfig.MinimumOwnSpins = 20
MarketConfig.MinimumPlaySeconds = 3600
return table.freeze(MarketConfig)
