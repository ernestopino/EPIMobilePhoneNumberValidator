//
//  EPICountry.h
//  EPIMobilePhoneNumberValidator
//
//  Created by Ernesto Pino on 25/2/16.
//  Copyright © 2016 EPINOM. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EPICountry : NSObject

@property (nonatomic, strong) NSString *isoCode;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *phoneCode;

@end
