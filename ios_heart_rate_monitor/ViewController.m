//
//  ViewController.m
//  ios_heart_rate_monitor
//
//  Created by Maxim Bilan on 4/21/14.
//  Copyright (c) 2014 Maxim Bilan. All rights reserved.
//

#import "ViewController.h"
#import "WaitSpinner.h"

@interface ViewController ()
{
    HeartRateMonitor *heartRateMonitor;
    BOOL deviceWasFound;
    
    WaitSpinner *waitSpinner;
}

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    waitSpinner = [[WaitSpinner alloc] init];
    
    heartRateMonitor = [[HeartRateMonitor alloc] init];
    heartRateMonitor.hrmDelegate = self;
    
    deviceWasFound = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [waitSpinner showInView:self.view];
    [heartRateMonitor startScan];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [heartRateMonitor stopScan];
}

#pragma mark - HeartRateMonitorDelegate

- (void)updateHRM:(NSString *)data
{
    if (!deviceWasFound) {
        deviceWasFound = YES;
        
        [waitSpinner hide];
    }
    
    if (data.length > 0) {
        NSLog(@"%@", data);
    }
}

- (void)scanningDidTimeout
{
    [waitSpinner hide];
    [heartRateMonitor stopScan];
    
    NSLog(@"Doesn't find any devices...");
}

- (void)connectionDidTimeout
{
    [waitSpinner hide];
    NSLog(@"Connection timeout...");
}

- (void)disconnection
{
    [waitSpinner hide];
    NSLog(@"Disconnection...");
}

@end
