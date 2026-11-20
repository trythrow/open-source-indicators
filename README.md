# Open Source Indicators

Open-source custom indicators for MetaTrader 5, written in MQL5.

## Available indicators

<table>
  <thead>
    <tr>
      <th width="35%">Indicator</th>
      <th width="65%">Screenshot</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td valign="top">
        <strong>Zero Lag Trend Signals (MTF)</strong>
        <p>A zero-lag exponential moving average with Wilder ATR deviation bands, bullish and bearish trend reversal and entry signals, a five-timeframe trend dashboard, and configurable popup alerts on closed bars.</p>
        <a href="https://raw.githubusercontent.com/trythrow/open-source-indicators/main/zero_lag_trend_signals.mq5">Download MQL5 source</a>
      </td>
      <td valign="top">
        <a href="screenshots/zero-lag-trend-signals.png">
          <img src="screenshots/zero-lag-trend-signals.png" alt="Zero Lag Trend Signals on an EURUSD M5 chart" width="800">
        </a>
      </td>
    </tr>
  </tbody>
</table>

## Installation

1. Download the indicator's raw `.mq5` source file.
2. In MetaTrader 5, select **File → Open Data Folder** and copy the file into `MQL5/Indicators`.
3. Open the file in MetaEditor and compile it with **F7**.
4. Refresh the **Indicators** list in MetaTrader 5's Navigator and attach the indicator to a chart.

## License and attribution

Distributed under the [Mozilla Public License 2.0](LICENSE).

Zero Lag Trend Signals (MTF) is adapted from AlgoAlpha's original Pine Script indicator. The MQL5 port and adaptation are by Ahmad Said. See the [source file](zero_lag_trend_signals.mq5) for attribution and license notices.
