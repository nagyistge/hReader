//
//  HRBMIVitalAppletTile.m
//  HReader
//
//  Created by Marshall Huss on 4/16/12.
//  Copyright (c) 2012 MITRE Corporation. All rights reserved.
//

#import "HRBMIVitalAppletTile.h"
#import "HRKeyValueTableViewController.h"
#import "HRSparkLineView.h"
#import "HRMEntry.h"

#import "NSDate+FormattedDate.h"
#import "NSArray+Collect.h"

@interface HRBMIVitalAppletTile () {
@private
    NSArray * __strong __entries;
}

- (double)normalLow;
- (double)normalHigh;
- (BOOL)isValueNormal:(double)value;
- (NSDictionary *)bmiChartForGender:(HRMPatientGender)gender;
- (NSInteger)percentileForBMIEntry:(HRMEntry *)entry;
- (BOOL)isChild;
- (NSInteger)monthsForDate:(NSDate *)date;

@end

@implementation HRBMIVitalAppletTile

- (void)tileDidLoad {
    [super tileDidLoad];
    
    // save points
    __entries = [self.patient vitalSignsWithType:@"BMI"];
    HRMEntry *latest = [__entries lastObject];
    
    // set labels
    float latestValue = [[latest valueForKeyPath:@"value.scalar"] floatValue];
    self.leftValueLabel.textColor = ([self isValueNormal:latestValue]) ? [UIColor blackColor] : [HRConfig redColor];
    self.middleValueLabel.text = [latest.date shortStyleDate];
    
    HRSparkLineRange range;
    HRSparkLineLine *line = [[HRSparkLineLine alloc] init];
    line.outOfRangeDotColor = [HRConfig redColor];
    line.weight = 4.0;
    line.points = [self dataForSparkLineView];
    
    float val = [[latest valueForKeyPath:@"value.scalar"] floatValue];
    
    if ([self isChild]) {
        self.leftTitleLabel.text = [@"percentile:" uppercaseString];
        self.leftValueLabel.text = [NSString stringWithFormat:@"%ld", [self percentileForBMIEntry:latest]];
        self.rightValueLabel.text = @"25th-75th";
        
        // display normal value
        NSInteger percentile = [self percentileForBMIEntry:latest];
        if ((percentile >= 25) || (percentile <= 75)) {
            self.rightValueLabel.textColor = [UIColor blackColor];
        }
        else {
            self.rightValueLabel.textColor = [HRConfig redColor];
        }
        
        range = HRMakeRange(25.0, 75.0 - 25.0);
    }
    else {
        self.leftTitleLabel.text = [@"recent result:" uppercaseString];
        self.leftValueLabel.text = [NSString stringWithFormat:@"%0.1f", latestValue];  
        self.rightValueLabel.text = [NSString stringWithFormat:@"%0.0f-%0.0f", [self normalLow], [self normalHigh]];
        
        // display normal value
        self.rightValueLabel.textColor = ([self isValueNormal:val]) ? [UIColor blackColor] : [HRConfig redColor];
        
        range = HRMakeRange([self normalLow], [self normalHigh] - [self normalLow]);
    }
    
    // sparkline
    line.range = range;
    self.sparkLineView.lines = [NSArray arrayWithObject:line];
    
}

- (NSArray *)dataForKeyValueTable {
    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:[__entries count]];
    [__entries enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(HRMEntry *entry, NSUInteger index, BOOL *stop) {
        double value = [[entry.value objectForKey:@"scalar"] doubleValue];
        BOOL isNormal = [self isValueNormal:value];
        UIColor *color = isNormal ? [UIColor blackColor] : [HRConfig redColor];
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSString stringWithFormat:@"%0.1f", value], @"detail",
                                    [entry.date mediumStyleDate], @"title",
                                    color, @"detail_color",
                                    nil];
        [entries addObject:dictionary];
    }];
    
    return [entries copy];
}

- (NSString *)titleForKeyValueTable {
    return self.titleLabel.text;
}

- (NSArray *)dataForSparkLineView {
    NSMutableArray *points = [[NSMutableArray alloc] initWithCapacity:[__entries count]];
    [__entries enumerateObjectsUsingBlock:^(HRMEntry *entry, NSUInteger index, BOOL *stop) {
        NSTimeInterval timeInterval = [entry.date timeIntervalSince1970];
        CGFloat value = 0.0;
        if ([self isChild]) {
            value = [self percentileForBMIEntry:entry];
        }
        else {        
            NSString *scalarString = [entry.value objectForKey:@"scalar"];
            if ([scalarString isKindOfClass:[NSString class]]) {
                value = [scalarString floatValue];    
            }
        }
        HRSparkLinePoint *point = [HRSparkLinePoint pointWithX:timeInterval y:value];
        [points addObject:point];
    }];
    return points;
}

#pragma mark - private

- (double)normalLow {
    return 18.0;
}

- (double)normalHigh {
    return 25.0;
}

- (BOOL)isValueNormal:(double)value {
    return (value >= [self normalLow] && value <= [self normalHigh]);
}


- (NSDictionary *)bmiChartForGender:(HRMPatientGender)gender {
    static NSDictionary *femaleBMIChart;
    static NSDictionary *maleBMIChart;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        NSURL *maleURL = [[NSBundle mainBundle] URLForResource:@"male-bmi-chart" withExtension:@"json"];
        NSData *maleData = [NSData dataWithContentsOfURL:maleURL];
        maleBMIChart = [NSJSONSerialization JSONObjectWithData:maleData options:0 error:nil];        
        NSAssert(error == nil, @"Error parsing male bmi chart %@", error);
        
        NSURL *femaleURL = [[NSBundle mainBundle] URLForResource:@"female-bmi-chart" withExtension:@"json"];
        NSData *femaleData = [NSData dataWithContentsOfURL:femaleURL];
        femaleBMIChart = [NSJSONSerialization JSONObjectWithData:femaleData options:0 error:&error];
        NSAssert(error == nil, @"Error parsing female bmi chart %@", error);
    });
    
    if (gender == HRMPatientGenderMale) {
        return maleBMIChart;
    }
    else {
        return femaleBMIChart;
    }
}

- (NSInteger)percentileForBMIEntry:(HRMEntry *)entry {
    NSString *scalarString = [entry.value objectForKey:@"scalar"];
    CGFloat bmi = 0.0;
    if ([scalarString isKindOfClass:[NSString class]]) {
        bmi = [scalarString floatValue];
    }
    
    NSDictionary *bmiChart = [self bmiChartForGender:[self.patient.gender intValue]];
    
    // Chart uses half months as the keys, so 30 months will be looked up as 30.5
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *monthComponents = [calendar components:NSMonthCalendarUnit fromDate:self.patient.dateOfBirth toDate:entry.date options:0];    
    NSInteger months = [monthComponents month];
    NSArray *row = [bmiChart objectForKey:[NSString stringWithFormat:@"%ld.5", (long)months]];
    
    __block NSInteger percentile = 0;
    [row enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSNumber *bmiValue, NSUInteger index, BOOL *stop) {
        if (bmi > [bmiValue floatValue]) {
            if (index == 0) {
                percentile = 3;
            }
            else if (index == [row count] - 1) {
                percentile = 97;
            }
            else {
                percentile = index * 5;                
            }
            *stop = YES;
        }
    }];
    
    if (percentile == 0) {
        percentile = 3;
    }
    return percentile;
}

- (BOOL)isChild {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *monthComponents = [calendar components:NSMonthCalendarUnit fromDate:self.patient.dateOfBirth toDate:[NSDate date] options:0];    
    return [monthComponents month] <= 240;
}

- (NSInteger)monthsForDate:(NSDate *)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *monthComponents = [calendar components:NSMonthCalendarUnit fromDate:date toDate:[NSDate date] options:0];    
    return [monthComponents month];
}

@end
