//
//  HCRefreshCommand.m
//  Uebersicht
//
//  Created by Felix Hageloh on 2/1/17.
//  Copyright © 2017 tracesOf. All rights reserved.
//

#import "HCRefreshCommand.h"
#import "AppDelegate.h"

@implementation HCRefreshCommand

-(id)performDefaultImplementation
{
    [(AppDelegate*)[NSApp delegate] refreshWidgets:self];
    return nil;
}

@end
