//
//  Helpers.h
//  HTTPServer
//
//  Created by Daniel Eggert on 27/04/2015.
//  Copyright (c) 2015 Wire. All rights reserved.
//

#import <Foundation/Foundation.h>



extern int SocketHelper_fcntl_setFlags(int const fildes, int const flag);
extern int SocketHelper_fcntl_getFlags(int const fildes);

extern NSString *HTTPMessageHeaderField(CFHTTPMessageRef message, NSString *field);


extern size_t offsetOf__sin_addr__in__sockaddr_in(void);
