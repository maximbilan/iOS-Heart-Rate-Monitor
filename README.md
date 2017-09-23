iOS Heart Rate Monitor
======================

The sample for working with heart rate devices was tested on Alpha MIO devices.<br>
Based on https://github.com/liquidx/CoreBluetoothPeripheral and https://github.com/timburks/iOSHeartRateMonitor sources.

## Using

Add to your project the next source files: <br>
<pre>
<i>HeartRateMonitor.h
HeartRateMonitor.m</i>
</pre>
You should use the <i>HeartRateMonitorDelegate</i> protocol.<br>
For example:<br>
<pre>
@interface ViewController : UIViewController &#60;HeartRateMonitorDelegate&#62;

@end
</pre>
And then you should implement the next methods:<br>
<pre>
// Returns value from device in real time
- (void)updateHRM:(NSString *)data;

// Called when scanning timeout occured
- (void)scanningDidTimeout;

// Called when connection timeout occured
- (void)connectionDidTimeout;

// Called when disconnection occured
- (void)disconnection;
</pre>

Initialization:<br>
<pre>
HeartRateMonitor *heartRateMonitor = [[HeartRateMonitor alloc] init];
heartRateMonitor.hrmDelegate = self;
</pre>

For start scanning:<br>
<pre>
[heartRateMonitor startScan];
</pre>

For stopping:<br>
<pre>
[heartRateMonitor stopScan];
</pre>
