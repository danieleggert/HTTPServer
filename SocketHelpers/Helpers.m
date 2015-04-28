//
//  Helpers.m
//  HTTPServer
//
//  Created by Daniel Eggert on 27/04/2015.
//  Copyright (c) 2015 Wire. All rights reserved.
//

#import "Helpers.h"

#import <sys/fcntl.h>
#import <netinet/in.h>



int SocketHelper_fcntl_setFlag(int const fildes, int const flag)
{
    return fcntl(fildes, F_SETFL, flag);
}

int SocketHelper_fcntl_getFlag(int const fildes, int const flag)
{
    return fcntl(fildes, F_GETFL);
}

NSString *HTTPMessageHeaderField(CFHTTPMessageRef message, NSString *field)
{
    return CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(message, (__bridge CFStringRef) field));
}

size_t offsetOf__sin_addr__in__sockaddr_in(void)
{
    return offsetof(struct sockaddr_in, sin_addr);
}
