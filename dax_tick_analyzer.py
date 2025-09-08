#!/usr/bin/env python3
"""
DAX Tick Data Strategy Analyzer
Analyzes tick data to determine optimal trading strategy for DAX
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

class DAXTickAnalyzer:
    def __init__(self, csv_file):
        """Initialize the analyzer with tick data"""
        self.csv_file = csv_file
        self.df = None
        self.analysis_results = {}
        
    def load_data(self):
        """Load and preprocess tick data"""
        print("Loading tick data...")
        
        # Load data with proper separator
        self.df = pd.read_csv(self.csv_file, sep='\t')
        
        # Clean column names
        self.df.columns = [col.strip('<>') for col in self.df.columns]
        
        # Combine date and time
        self.df['datetime'] = pd.to_datetime(self.df['DATE'] + ' ' + self.df['TIME'])
        self.df.set_index('datetime', inplace=True)
        
        # Calculate mid price and spread
        self.df['mid_price'] = (self.df['BID'] + self.df['ASK']) / 2
        self.df['spread'] = self.df['ASK'] - self.df['BID']
        self.df['spread_bps'] = (self.df['spread'] / self.df['mid_price']) * 10000
        
        # Remove invalid data
        self.df = self.df.dropna(subset=['BID', 'ASK'])
        
        print(f"Loaded {len(self.df):,} tick records")
        print(f"Date range: {self.df.index.min()} to {self.df.index.max()}")
        print(f"Total days: {(self.df.index.max() - self.df.index.min()).days}")
        
        return self.df
    
    def basic_statistics(self):
        """Calculate basic market statistics"""
        print("\n" + "="*50)
        print("BASIC MARKET STATISTICS")
        print("="*50)
        
        # Calculate unique trading days
        unique_dates = pd.Series(self.df.index.date).nunique()

        stats = {
            'total_ticks': len(self.df),
            'trading_days': unique_dates,
            'avg_ticks_per_day': len(self.df) / unique_dates,
            'price_range': {
                'min': self.df['mid_price'].min(),
                'max': self.df['mid_price'].max(),
                'range': self.df['mid_price'].max() - self.df['mid_price'].min()
            },
            'spread_stats': {
                'avg_spread': self.df['spread'].mean(),
                'avg_spread_bps': self.df['spread_bps'].mean(),
                'min_spread': self.df['spread'].min(),
                'max_spread': self.df['spread'].max()
            }
        }
        
        print(f"Total ticks: {stats['total_ticks']:,}")
        print(f"Trading days: {stats['trading_days']}")
        print(f"Average ticks per day: {stats['avg_ticks_per_day']:,.0f}")
        print(f"Price range: {stats['price_range']['min']:.1f} - {stats['price_range']['max']:.1f}")
        print(f"Total range: {stats['price_range']['range']:.1f} points")
        print(f"Average spread: {stats['spread_stats']['avg_spread']:.2f} points")
        print(f"Average spread: {stats['spread_stats']['avg_spread_bps']:.1f} bps")
        
        self.analysis_results['basic_stats'] = stats
        return stats
    
    def analyze_trading_sessions(self):
        """Analyze activity by trading session"""
        print("\n" + "="*50)
        print("TRADING SESSION ANALYSIS")
        print("="*50)
        
        # Add hour column
        self.df['hour'] = self.df.index.hour
        
        # Define sessions (CET time)
        sessions = {
            'Asian': (0, 8),
            'European': (8, 17),
            'US_Overlap': (14, 17),
            'After_Hours': (17, 24)
        }
        
        session_stats = {}
        
        for session_name, (start_hour, end_hour) in sessions.items():
            if start_hour < end_hour:
                session_data = self.df[(self.df['hour'] >= start_hour) & (self.df['hour'] < end_hour)]
            else:  # Overnight session
                session_data = self.df[(self.df['hour'] >= start_hour) | (self.df['hour'] < end_hour)]
            
            if len(session_data) > 0:
                # Calculate price movements
                session_data = session_data.copy()
                session_data['price_change'] = session_data['mid_price'].diff()
                session_data['abs_price_change'] = session_data['price_change'].abs()
                
                stats = {
                    'tick_count': len(session_data),
                    'avg_spread': session_data['spread'].mean(),
                    'volatility': session_data['price_change'].std(),
                    'avg_move_size': session_data['abs_price_change'].mean(),
                    'max_move': session_data['abs_price_change'].max(),
                    'activity_score': len(session_data) * session_data['abs_price_change'].mean()
                }
                
                session_stats[session_name] = stats
                
                print(f"\n{session_name} Session ({start_hour:02d}:00-{end_hour:02d}:00):")
                print(f"  Ticks: {stats['tick_count']:,}")
                print(f"  Avg spread: {stats['avg_spread']:.2f} points")
                print(f"  Volatility: {stats['volatility']:.2f}")
                print(f"  Avg move: {stats['avg_move_size']:.2f} points")
                print(f"  Activity score: {stats['activity_score']:.0f}")
        
        # Find best session
        best_session = max(session_stats.keys(), key=lambda x: session_stats[x]['activity_score'])
        print(f"\nMOST ACTIVE SESSION: {best_session}")
        
        self.analysis_results['session_stats'] = session_stats
        self.analysis_results['best_session'] = best_session
        
        return session_stats
    
    def analyze_volatility_regimes(self):
        """Identify volatility regimes and patterns"""
        print("\n" + "="*50)
        print("VOLATILITY REGIME ANALYSIS")
        print("="*50)
        
        # Calculate rolling volatility (5-minute windows)
        self.df['price_change'] = self.df['mid_price'].diff()
        self.df['abs_change'] = self.df['price_change'].abs()
        
        # Rolling volatility
        self.df['volatility_5min'] = self.df['abs_change'].rolling('5min').std()
        self.df['volatility_15min'] = self.df['abs_change'].rolling('15min').std()
        self.df['volatility_1h'] = self.df['abs_change'].rolling('1h').std()
        
        # Define volatility regimes
        vol_5min = self.df['volatility_5min'].dropna()
        vol_thresholds = {
            'low': vol_5min.quantile(0.33),
            'medium': vol_5min.quantile(0.67),
            'high': vol_5min.quantile(1.0)
        }
        
        def classify_volatility(vol):
            if pd.isna(vol):
                return 'unknown'
            elif vol <= vol_thresholds['low']:
                return 'low'
            elif vol <= vol_thresholds['medium']:
                return 'medium'
            else:
                return 'high'
        
        self.df['vol_regime'] = self.df['volatility_5min'].apply(classify_volatility)
        
        # Analyze each regime
        regime_stats = {}
        for regime in ['low', 'medium', 'high']:
            regime_data = self.df[self.df['vol_regime'] == regime]
            if len(regime_data) > 0:
                stats = {
                    'percentage': len(regime_data) / len(self.df) * 100,
                    'avg_spread': regime_data['spread'].mean(),
                    'avg_move': regime_data['abs_change'].mean(),
                    'tick_frequency': len(regime_data) / (len(regime_data) / len(self.df) * 
                                                        (self.df.index.max() - self.df.index.min()).total_seconds() / 3600)
                }
                regime_stats[regime] = stats
                
                print(f"\n{regime.upper()} Volatility Regime:")
                print(f"  Time in regime: {stats['percentage']:.1f}%")
                print(f"  Avg spread: {stats['avg_spread']:.2f} points")
                print(f"  Avg move size: {stats['avg_move']:.3f} points")
                print(f"  Tick frequency: {stats['tick_frequency']:.1f} ticks/hour")
        
        self.analysis_results['volatility_regimes'] = regime_stats
        self.analysis_results['vol_thresholds'] = vol_thresholds
        
        return regime_stats
    
    def analyze_price_patterns(self):
        """Analyze price movement patterns for strategy identification"""
        print("\n" + "="*50)
        print("PRICE PATTERN ANALYSIS")
        print("="*50)
        
        # Calculate various timeframe returns
        timeframes = ['1min', '5min', '15min', '30min', '1h']
        pattern_stats = {}
        
        for tf in timeframes:
            # Resample to timeframe
            tf_data = self.df['mid_price'].resample(tf).ohlc()
            tf_data = tf_data.dropna()
            
            if len(tf_data) > 1:
                # Calculate returns and statistics
                tf_data['returns'] = tf_data['close'].pct_change()
                tf_data['range'] = tf_data['high'] - tf_data['low']
                tf_data['body'] = abs(tf_data['close'] - tf_data['open'])
                tf_data['upper_wick'] = tf_data['high'] - tf_data[['open', 'close']].max(axis=1)
                tf_data['lower_wick'] = tf_data[['open', 'close']].min(axis=1) - tf_data['low']
                
                # Pattern analysis
                stats = {
                    'mean_return': tf_data['returns'].mean() * 100,
                    'volatility': tf_data['returns'].std() * 100,
                    'avg_range': tf_data['range'].mean(),
                    'avg_body_ratio': (tf_data['body'] / tf_data['range']).mean(),
                    'trend_persistence': self.calculate_trend_persistence(tf_data['returns']),
                    'mean_reversion_strength': self.calculate_mean_reversion(tf_data['returns'])
                }
                
                pattern_stats[tf] = stats
                
                print(f"\n{tf.upper()} Timeframe:")
                print(f"  Avg return: {stats['mean_return']:.4f}%")
                print(f"  Volatility: {stats['volatility']:.2f}%")
                print(f"  Avg range: {stats['avg_range']:.2f} points")
                print(f"  Body ratio: {stats['avg_body_ratio']:.2f}")
                print(f"  Trend persistence: {stats['trend_persistence']:.2f}")
                print(f"  Mean reversion: {stats['mean_reversion_strength']:.2f}")
        
        self.analysis_results['pattern_stats'] = pattern_stats
        return pattern_stats
    
    def calculate_trend_persistence(self, returns):
        """Calculate how often price continues in same direction"""
        if len(returns) < 2:
            return 0
        
        same_direction = 0
        total_pairs = 0
        
        for i in range(1, len(returns)):
            if not (pd.isna(returns.iloc[i]) or pd.isna(returns.iloc[i-1])):
                if (returns.iloc[i] > 0 and returns.iloc[i-1] > 0) or \
                   (returns.iloc[i] < 0 and returns.iloc[i-1] < 0):
                    same_direction += 1
                total_pairs += 1
        
        return same_direction / total_pairs if total_pairs > 0 else 0
    
    def calculate_mean_reversion(self, returns):
        """Calculate mean reversion tendency"""
        if len(returns) < 2:
            return 0
        
        reversals = 0
        total_pairs = 0
        
        for i in range(1, len(returns)):
            if not (pd.isna(returns.iloc[i]) or pd.isna(returns.iloc[i-1])):
                if (returns.iloc[i] > 0 and returns.iloc[i-1] < 0) or \
                   (returns.iloc[i] < 0 and returns.iloc[i-1] > 0):
                    reversals += 1
                total_pairs += 1
        
        return reversals / total_pairs if total_pairs > 0 else 0

    def recommend_strategy(self):
        """Recommend optimal trading strategy based on analysis"""
        print("\n" + "="*60)
        print("STRATEGY RECOMMENDATION")
        print("="*60)

        # Get analysis results
        basic_stats = self.analysis_results.get('basic_stats', {})
        session_stats = self.analysis_results.get('session_stats', {})
        vol_regimes = self.analysis_results.get('volatility_regimes', {})
        pattern_stats = self.analysis_results.get('pattern_stats', {})

        recommendations = {}

        # Analyze spread characteristics
        avg_spread = basic_stats.get('spread_stats', {}).get('avg_spread', 0)
        if avg_spread < 2.0:
            spread_score = "EXCELLENT for scalping"
        elif avg_spread < 4.0:
            spread_score = "GOOD for scalping"
        else:
            spread_score = "POOR for scalping - consider swing trading"

        # Analyze volatility for strategy selection
        if vol_regimes:
            high_vol_time = vol_regimes.get('high', {}).get('percentage', 0)
            low_vol_time = vol_regimes.get('low', {}).get('percentage', 0)

            if high_vol_time > 40:
                vol_strategy = "BREAKOUT strategy - high volatility periods"
            elif low_vol_time > 50:
                vol_strategy = "MEAN REVERSION strategy - low volatility dominates"
            else:
                vol_strategy = "HYBRID strategy - mixed volatility regimes"
        else:
            vol_strategy = "Unable to determine"

        # Analyze trend vs mean reversion characteristics
        trend_scores = []
        reversion_scores = []

        for tf, stats in pattern_stats.items():
            if tf in ['1min', '5min']:  # Focus on scalping timeframes
                trend_scores.append(stats.get('trend_persistence', 0))
                reversion_scores.append(stats.get('mean_reversion_strength', 0))

        avg_trend = np.mean(trend_scores) if trend_scores else 0
        avg_reversion = np.mean(reversion_scores) if reversion_scores else 0

        if avg_trend > 0.55:
            momentum_strategy = "MOMENTUM/TREND FOLLOWING"
        elif avg_reversion > 0.55:
            momentum_strategy = "MEAN REVERSION"
        else:
            momentum_strategy = "BALANCED (trend + reversion)"

        # Best trading session
        best_session = self.analysis_results.get('best_session', 'European')

        # Final recommendation
        print(f"SPREAD ANALYSIS: {spread_score}")
        print(f"VOLATILITY STRATEGY: {vol_strategy}")
        print(f"MOMENTUM ANALYSIS: {momentum_strategy}")
        print(f"OPTIMAL SESSION: {best_session}")

        # Specific strategy recommendations
        print(f"\n🎯 PRIMARY STRATEGY RECOMMENDATIONS:")

        if avg_spread < 3.0 and avg_trend > 0.52:
            print("1. SCALPING + MOMENTUM")
            print("   - 1-5 minute timeframes")
            print("   - Tight stops (10-20 points)")
            print("   - Quick profits (15-30 points)")
            print("   - Trade during high activity sessions")

        elif avg_reversion > 0.52:
            print("1. MEAN REVERSION SCALPING")
            print("   - Trade against short-term moves")
            print("   - Use support/resistance levels")
            print("   - Smaller position sizes")
            print("   - Quick exits on reversal")

        if high_vol_time > 30:
            print("2. BREAKOUT STRATEGY")
            print("   - Trade volatility expansions")
            print("   - Use wider stops (30-50 points)")
            print("   - Target larger moves (50-100 points)")
            print("   - Focus on session opens/news")

        # MT5 EA parameter recommendations
        print(f"\n⚙️ MT5 EA PARAMETER RECOMMENDATIONS:")
        print(f"StopLoss: {max(20, int(avg_spread * 8))} points")
        print(f"TakeProfit: {max(40, int(avg_spread * 15))} points")
        print(f"MaxSpread: {max(5, int(avg_spread * 2))} points")
        print(f"LotSize: Start with 0.01-0.1 (based on volatility)")

        if best_session == 'European':
            print("TradingHours: 08:00-17:00 CET")
        elif best_session == 'US_Overlap':
            print("TradingHours: 14:00-17:00 CET")

        recommendations.update({
            'spread_score': spread_score,
            'volatility_strategy': vol_strategy,
            'momentum_strategy': momentum_strategy,
            'best_session': best_session,
            'suggested_stop': max(20, int(avg_spread * 8)),
            'suggested_target': max(40, int(avg_spread * 15)),
            'suggested_max_spread': max(5, int(avg_spread * 2))
        })

        self.analysis_results['recommendations'] = recommendations
        return recommendations

    def run_full_analysis(self):
        """Run complete analysis pipeline"""
        print("🚀 Starting DAX Tick Data Strategy Analysis...")

        # Load data
        self.load_data()

        # Run all analyses
        self.basic_statistics()
        self.analyze_trading_sessions()
        self.analyze_volatility_regimes()
        self.analyze_price_patterns()

        # Generate recommendations
        self.recommend_strategy()

        print(f"\n✅ Analysis complete! Results saved to analyzer object.")
        return self.analysis_results

def main():
    """Main execution function"""
    analyzer = DAXTickAnalyzer('GER40_ticks.csv')
    results = analyzer.run_full_analysis()

    # Save results to file
    import json
    with open('dax_analysis_results.json', 'w') as f:
        # Convert numpy types to native Python types for JSON serialization
        def convert_numpy(obj):
            if isinstance(obj, np.integer):
                return int(obj)
            elif isinstance(obj, np.floating):
                return float(obj)
            elif isinstance(obj, np.ndarray):
                return obj.tolist()
            return obj

        json_results = json.loads(json.dumps(results, default=convert_numpy))
        json.dump(json_results, f, indent=2)

    print(f"\n📊 Detailed results saved to: dax_analysis_results.json")

if __name__ == "__main__":
    main()
