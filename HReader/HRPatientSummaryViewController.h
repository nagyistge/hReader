//
//  HRPatientSummarySplitViewController.h
//  HReader
//
//  Created by Marshall Huss on 11/30/11.
//  Copyright (c) 2011 MITRE Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HRPatientSwipeViewController;

@interface HRPatientSummaryViewController : UIViewController <UIScrollViewDelegate>

@property (retain, nonatomic) IBOutlet UIView *patientHeaderView;
@property (retain, nonatomic) IBOutlet UIScrollView *patientScrollView;
@property (retain, nonatomic) IBOutlet UIView *patientSummaryView;
@property (retain, nonatomic) IBOutlet UILabel *patientName;

@property (retain, nonatomic) IBOutlet UILabel *addressLabel;
@property (retain, nonatomic) IBOutlet UILabel *genderLabel;
@property (retain, nonatomic) IBOutlet UILabel *ageLabel;
@property (retain, nonatomic) IBOutlet UILabel *dobLabel;
@property (retain, nonatomic) IBOutlet UILabel *placeOfBirthLabel;
@property (retain, nonatomic) IBOutlet UILabel *raceLabel;
@property (retain, nonatomic) IBOutlet UILabel *ethnicityLabel;
@property (retain, nonatomic) IBOutlet UILabel *phoneNumberLabel;

@property (retain, nonatomic) NSArray *labelsArray;

@end