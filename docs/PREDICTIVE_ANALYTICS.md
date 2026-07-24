# Predictive Analytics

Analyzes historical trends to predict future device behavior and risks, with confidence scores.

## Prediction Models

### Battery Degradation
Predicts remaining battery capacity based on cycle count and device age.
- Linear regression model: ~2% per 100 cycles + age factor
- Confidence decreases with age (>365 days: -5%)

### Storage Exhaustion
Forecasts days until storage reaches 100% capacity.
- Based on daily growth rate (default: 0.5%/day)
- Returns "days_to_full" — days until storage exhaustion

### Thermal Instability
Assesses risk of reaching critical temperature threshold.
- Risk levels: low, moderate, high, critical
- Margin = threshold - current temp

### Performance Degradation
Evaluates risk based on memory and storage pressure.
- Critical when mem > 90%
- High when mem > 80%
- Moderate when storage > 90%

### Security Risks
Evaluates security posture trends.
- Based on security score from Health Intelligence
- Patch age and SELinux status factored in

## Confidence Scoring

Each prediction includes a confidence percentage:
- 85-100%: High confidence (sufficient data)
- 65-84%: Moderate confidence
- 50-64%: Low confidence (limited data)
- <50%: Insufficient data

## Usage

| Key | Action |
|-----|--------|
| `r` | Refresh all predictions |
| `d` | View detailed report of all predictions |

## API

```bash
predictive_battery_degradation [health] [cycles]
predictive_storage_exhaustion [pct] [growth]
predictive_thermal_instability [temp] [threshold]
predictive_performance_degradation [mem] [storage]
predictive_security_risks
predictive_all  # Run all predictions
```
