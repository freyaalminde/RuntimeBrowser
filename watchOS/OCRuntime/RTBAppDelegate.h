//
//  AppDelegate.h
//  OCRuntime
//
//  Created by Nicolas Seriot on 6/14/13.
//  Copyright (c) 2013 Nicolas Seriot. All rights reserved.
//

#import "GCDWebServer.h"

@class RTBRuntime;

@interface RTBAppDelegate : NSObject

@property (strong, nonatomic) RTBRuntime *allClasses;
@property (strong, nonatomic) GCDWebServer *webServer;

- (GCDWebServerResponse *)responseForPath:(NSString *)path;
- (NSString *)myIPAddress;
- (UInt16)serverPort;

- (void)stopWebServer;
- (void)startWebServer;

- (void)useClass:(NSString *)className;

- start;

@end
