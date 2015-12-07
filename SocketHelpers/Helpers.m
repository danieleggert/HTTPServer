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



int SocketHelper_fcntl_setFlags(int const fildes, int const flags)
{
    return fcntl(fildes, F_SETFL, flags);
}

int SocketHelper_fcntl_getFlags(int const fildes)
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
