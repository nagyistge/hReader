//
//  HRRootViewController_private.h
//  HReader
//
//  Created by Caleb Davenport on 6/4/12.
//  Copyright (c) 2012 MITRE Corporation. All rights reserved.
//

#import "HRPeoplePickerViewController.h"

@interface HRPeoplePickerViewController ()

/*
 
 Set the selected patient. This saves the patient identifier to user defaults
 and posts the appropriate change notification to all observers. This must
 be called on the main thread with a patient object that is created in the 
 main application managed object context.
 
 */
+ (void)setSelectedPatient:(HRMPatient *)patient;

/*
 
 Calls `selectedPatientInContext:` passing the main application context. This
 must be called on the main thread.
 
 */
+ (HRMPatient *)selectedPatient;

/*
 
 Fetch the selected patient from the provided context. This method will get the
 stored object id from user defaults and respond with a patient object.
 
 */
+ (HRMPatient *)selectedPatientInContext:(NSManagedObjectContext *)context;

@end
