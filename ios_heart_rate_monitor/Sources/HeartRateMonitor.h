//
//  HeartRateMonitor.h
//  ios_heart_rate_monitor
//
//  Created by Maxim Bilan on 21/04/14.
//  Copyright (c) 2014 Maxim Bilan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@protocol HeartRateMonitorDelegate

@required
- (void)updateHRM:(NSString *)data;

- (void)scanningDidTimeout;
- (void)connectionDidTimeout;
- (void)disconnection;

@end

@interface HeartRateMonitor : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (weak, nonatomic) id<HeartRateMonitorDelegate> hrmDelegate;

// Request CBCentralManager to scan for heart rate peripherals using service UUID 0x180D
- (void)startScan;

// Request CBCentralManager to stop scanning for heart rate peripherals
- (void) stopScan;

@end
