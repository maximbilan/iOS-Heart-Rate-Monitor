//
//  HeartRateMonitor.m
//  ios_heart_rate_monitor
//
//  Created by Maxim Bilan on 21/04/14.
//  Copyright (c) 2014 Maxim Bilan. All rights reserved.
//

#import "HeartRateMonitor.h"

static const NSTimeInterval HeartRateMonitorScanningTimeout     = 10.0;
static const NSTimeInterval HeartRateMonitorConnectingTimeout   = 10.0;

@interface HeartRateMonitor ()

@property (nonatomic, strong) NSMutableArray *heartRateMonitors;
@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) CBPeripheral *peripheral;

// Use CBCentralManager to check whether the current platform/hardware supports Bluetooth LE.
@property (NS_NONATOMIC_IOSONLY, getter=isLECapableHardware, readonly) BOOL LECapableHardware;

// Scanning timeout
- (void)startScanningTimeoutMonitor;
- (void)stopScanningTimeoutMonitor;
- (void)scanningDidTimeout;

// Connection timeout
- (void)startConnectionTimeoutMonitor:(CBPeripheral *)peripheral;
- (void)stopConnectionTimeoutMonitor:(CBPeripheral *)peripheral;
- (void)connectionDidTimeout:(CBPeripheral *)peripheral;
- (void)disconnection:(CBPeripheral *)peripheral;

@end

@implementation HeartRateMonitor

- (instancetype)init
{
    if (self = [super init]) {
        self.heartRateMonitors = [NSMutableArray array];
        self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    
    return self;
}

// Request CBCentralManager to scan for heart rate peripherals using service UUID 0x180D
- (void)startScan
{
    if ([self isLECapableHardware]) {
        [self.manager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@"180D"]] options:nil];
        [self startScanningTimeoutMonitor];
    }
}

// Request CBCentralManager to stop scanning for heart rate peripherals
- (void)stopScan
{
    if ([self isLECapableHardware]) {
        [self stopScanningTimeoutMonitor];
        [self.manager stopScan];
    }
}

// Use CBCentralManager to check whether the current platform/hardware supports Bluetooth LE.
- (BOOL)isLECapableHardware
{
    NSString *state = nil;
    switch ([self.manager state]) {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;
    }
    NSLog(@"Central manager state: %@", state);
    return FALSE;
}

- (void)dealloc
{
    [self.heartRateMonitors removeAllObjects];
    self.peripheral = nil;
    self.manager = nil;
}

#pragma mark - CBCentralManager delegate methods

// Invoked when the central manager's state is updated.
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self isLECapableHardware];
}

// Invoked when the central discovers heart rate peripheral while scanning.
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)aPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    [self stopScanningTimeoutMonitor];
    
    NSMutableArray *peripherals = [self mutableArrayValueForKey:@"heartRateMonitors"];
    if (![self.heartRateMonitors containsObject:aPeripheral])
        [peripherals addObject:aPeripheral];
	
    if (aPeripheral.identifier) {
        // Retrieve already known devices
		[self.manager retrievePeripheralsWithIdentifiers:@[aPeripheral.identifier]];
    }
    else {
        NSLog(@"Peripheral UUID is null");
        [self.manager connectPeripheral:aPeripheral options:nil];
        [self startConnectionTimeoutMonitor:aPeripheral];
    }
}

// Invoked when the central manager retrieves the list of known peripherals.
// Automatically connect to first known peripheral
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    NSLog(@"Retrieved peripheral: %lu - %@", (unsigned long)[peripherals count], peripherals);
    [self stopScan];
    
    // If there are any known devices, automatically connect to it.
    if ([peripherals count] >= 1) {
        self.peripheral = peripherals[0];
        [self.manager connectPeripheral:self.peripheral
                                options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: @YES}];
        [self startConnectionTimeoutMonitor:self.peripheral];
    }
}

// Invoked when a connection is succesfully created with the peripheral.
// Discover available services on the peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    NSLog(@"connected");
    [self stopConnectionTimeoutMonitor:aPeripheral];
    
    [aPeripheral setDelegate:self];
    [aPeripheral discoverServices:nil];
}

// Invoked when an existing connection with the peripheral is torn down.
// Reset local variables
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    if (self.peripheral) {
        [self stopConnectionTimeoutMonitor:self.peripheral];
        [self disconnection:self.peripheral];
        
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

// Invoked when the central manager fails to create a connection with the peripheral.
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    NSLog(@"Fail to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    if (self.peripheral) {
        [self stopConnectionTimeoutMonitor:self.peripheral];
        
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

#pragma mark - CBPeripheral delegate methods

// Invoked upon completion of a -[discoverServices:] request.
// Discover available characteristics on interested services
- (void)peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error
{
    for (CBService *aService in aPeripheral.services) {
        NSLog(@"Service found with UUID: %@", aService.UUID);
        
        /* Heart Rate Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180D"]]) {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
        
        /* Device Information Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180A"]]) {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
		
        /* GAP (Generic Access Profile) for Device Name */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"1800"]]) {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

// Invoked upon completion of a -[discoverCharacteristics:forService:] request.
// Perform appropriate operations on interested characteristics
- (void)peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180D"]]) {
        for (CBCharacteristic *aChar in service.characteristics) {
            // Set notification on heart rate measurement
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]) {
                [self.peripheral setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found a Heart Rate Measurement Characteristic");
            }
            
            // Read body sensor location
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]]) {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Body Sensor Location Characteristic");
            }
            
            // Write heart rate control point
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A39"]]) {
                uint8_t val = 1;
                NSData* valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
                [aPeripheral writeValue:valData forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
            }
        }
    }
    
    if ([service.UUID isEqual:[CBUUID UUIDWithString:@"1800"]]) {
        for (CBCharacteristic *aChar in service.characteristics) {
            // Read device name
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"0x180F"]]) {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Device Name Characteristic");
            }
        }
    }
    
    if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]]) {
        for (CBCharacteristic *aChar in service.characteristics) {
            // Read manufacturer name
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]]) {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Device Manufacturer Name Characteristic");
            }
        }
    }
}

// Update UI with heart rate data received from device
- (void)updateWithHRMData:(NSData *)data
{
    const uint8_t *reportData = [data bytes];
    uint16_t bpm = 0;
    
    if ((reportData[0] & 0x01) == 0) {
        // uint8 bpm
        bpm = reportData[1];
    }
    else {
        // uint16 bpm
        bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));
    }
    NSLog(@"bpm %d", bpm);
    
    if (self.hrmDelegate) {
        [self.hrmDelegate updateHRM:[NSString stringWithFormat:@"%d", bpm]];
    }
}

// Invoked upon completion of a -[readValueForCharacteristic:] request
// or on the reception of a notification/indication.
- (void)peripheral:(CBPeripheral *)aPeripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    // Updated value for heart rate measurement received
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]) {
        if(characteristic.value || !error) {
            NSLog(@"received value: %@", characteristic.value);
            // Update UI with heart rate data
            [self updateWithHRMData:characteristic.value];
        }
    }
    // Value for body sensor location received
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]]) {
        NSData *updatedValue = characteristic.value;
        uint8_t *dataPointer = (uint8_t *)[updatedValue bytes];
        if (dataPointer) {
            uint8_t location = dataPointer[0];
            NSString*  locationString;
            switch (location) {
                case 0:
                    locationString = @"Other";
                    break;
                case 1:
                    locationString = @"Chest";
                    break;
                case 2:
                    locationString = @"Wrist";
                    break;
                case 3:
                    locationString = @"Finger";
                    break;
                case 4:
                    locationString = @"Hand";
                    break;
                case 5:
                    locationString = @"Ear Lobe";
                    break;
                case 6:
                    locationString = @"Foot";
                    break;
                default:
                    locationString = @"Reserved";
                    break;
            }
            NSLog(@"Body Sensor Location = %@ (%d)", locationString, location);
        }
    }
    // Value for device Name received
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"0x180F"]]) {
        NSString * deviceName = [[NSString alloc] initWithData:characteristic.value
                                                      encoding:NSUTF8StringEncoding];
        NSLog(@"Device Name = %@", deviceName);
    }
    // Value for manufacturer name received
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]]) {
        NSString *manufacturer = [[NSString alloc] initWithData:characteristic.value
                                                       encoding:NSUTF8StringEncoding];
        NSLog(@"Manufacturer Name = %@", manufacturer);
    }
}

#pragma mark - Scanning Timeout

- (void)startScanningTimeoutMonitor
{
    [self stopScanningTimeoutMonitor];
    [self performSelector:@selector(scanningDidTimeout)
               withObject:nil
               afterDelay:HeartRateMonitorScanningTimeout];
}

- (void)stopScanningTimeoutMonitor
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(scanningDidTimeout)
                                               object:nil];
}

- (void)scanningDidTimeout
{
    if (self.hrmDelegate) {
        [self.hrmDelegate scanningDidTimeout];
    }
}

#pragma mark - Connection Timeout

- (void)startConnectionTimeoutMonitor:(CBPeripheral *)peripheral
{
    [self stopConnectionTimeoutMonitor:peripheral];
    [self performSelector:@selector(connectionDidTimeout:)
               withObject:nil
               afterDelay:HeartRateMonitorConnectingTimeout];
}

- (void)stopConnectionTimeoutMonitor:(CBPeripheral *)peripheral
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(connectionDidTimeout:)
                                               object:nil];
}

- (void)connectionDidTimeout:(CBPeripheral *)peripheral
{
    if (self.hrmDelegate) {
        [self.hrmDelegate connectionDidTimeout];
    }
}

- (void)disconnection:(CBPeripheral *)peripheral
{
    if (self.hrmDelegate) {
        [self.hrmDelegate disconnection];
    }
}

@end
