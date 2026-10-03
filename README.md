🎯 Sniper-Style Pro MT5 EA

Sniper-Style Pro EA is a MetaTrader 5 Expert Advisor designed around a simple technical signal system using EMA trend detection, RSI confirmation, and ATR-based risk/target levels.

The EA is designed to provide clear BUY/SELL signals while automatically managing Stop Loss and Take Profit levels.

⚙️ Core Strategy

The default configuration uses:

Fast EMA: 9
Slow EMA: 21
RSI: 14
Bullish RSI threshold: 52
Bearish RSI threshold: 48
ATR: 14
Stop Loss: 3 × ATR
TP1: 0.5R
TP2: 1.0R
TP3: 1.5R
Default lot size: 0.01
EMA trend alignment: Enabled
📊 Signal Logic

BUY

Fast EMA crosses above Slow EMA
RSI confirms bullish momentum
EMA trend alignment requirement is satisfied

SELL

Fast EMA crosses below Slow EMA
RSI confirms bearish momentum
EMA trend alignment requirement is satisfied
🎯 Trade Management

The EA calculates targets using the distance between the entry price and ATR-based Stop Loss:

Risk = ATR × Stop Distance

TP1 = 0.5R
TP2 = 1.0R
TP3 = 1.5R

TP3 is used as the final broker Take Profit by default.

Optional partial-profit management can be enabled for TP1 and TP2.

📈 Multi-Timeframe Trend Panel

The EA can monitor multiple timeframes:

M5
M15
M30
H1

This provides additional market-trend information while the EA is running.

🏷️ Historical Trade Results

One of the main features is historical trade-result labeling.

The EA can display:

BUY • TP3 HIT
BUY • SL HIT

SELL • TP3 HIT
SELL • SL HIT

This makes it easier to review previous EA trades directly on the MT5 chart.

🛡️ Risk Management

Available controls include:

Adjustable lot size
ATR-based Stop Loss
TP1 / TP2 / TP3
Optional partial closing
One-position-per-symbol mode
Magic number
Maximum execution deviation
Configurable trading settings
🧪 Recommended Testing

Always test the EA using:

MT5 Strategy Tester
Historical data
Different market conditions
Demo account
Forward testing

The default lot size is 0.01 for initial testing.

⚠️ Disclaimer

This Expert Advisor is an experimental algorithmic trading project and does not guarantee profitable results.

Trading financial markets involves substantial risk. Past backtest or demo performance does not guarantee future results. Always perform your own testing and risk assessment before using the EA with real funds.

📁 Project Structure
Sniper-Style-Pro-EA/
│
├── Sniper_Style_Pro_EA.mq5
├── README.md
└── LICENSE
🚀 Installation

Copy the .mq5 file into:

MetaTrader 5/
└── MQL5/
    └── Experts/
        └── Sniper_Style_Pro_EA.mq5

Then open MetaEditor, compile the EA, and attach it to an MT5 chart.
