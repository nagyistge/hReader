//
//  PINCodeSecurityQuestionsViewController.m
//  HReader
//
//  Created by Marshall Huss on 3/7/12.
//  Copyright (c) 2012 MITRE Corporation. All rights reserved.
//

#import <objc/message.h>

#import "PINSecurityQuestionsViewController.h"
#import "PINCodeTextField.h"
#import "PINCodeViewController.h"

#if !__has_feature(objc_arc)
#error This class requires ARC
#endif

@interface PINSecurityQuestionsViewController () {
    NSMutableDictionary *data;
}

- (void)updateDoneButtonEnabledState;

@end

@implementation PINSecurityQuestionsViewController

@synthesize tableView = _tableView;
@synthesize mode = _mode;
@synthesize delegate = _delegate;
@synthesize action = _action;

#pragma mark - object methods

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        data = [[NSMutableDictionary alloc] init];
        _mode = 0;
    }
    return self;
}

- (void)setMode:(PINSecurityQuestionsViewControllerMode)mode {
    NSAssert((mode > 0 && mode < 4), @"You must provide a valid mode");
    if (_mode == 0) { _mode = mode; }
}

#pragma mark - view lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    NSAssert(self.mode > 0, @"The security question mode must be set");
    NSAssert(self.delegate > 0, @"The delegate must be set");
    NSAssert(self.action > 0, @"The action must be set");
    UIImage *backgroundImage = [UIImage imageNamed:@"PINCodeBackground"];
    self.view.backgroundColor = [UIColor colorWithPatternImage:backgroundImage];
    self.tableView.backgroundView = nil;
    if (self.mode != PINSecurityQuestionsViewControllerCreate) {
        NSArray *array = [self.delegate securityQuestions];
        [array enumerateObjectsUsingBlock:^(NSString *question, NSUInteger idx, BOOL *stop) {
            [data setObject:question forKey:[NSString stringWithFormat:@"Question%lx", (unsigned long)idx]];
        }];
    }
    [self updateDoneButtonEnabledState];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}


#pragma mark - text fields

- (BOOL)textFieldShouldReturn:(UITextField *)field {
    return YES;
}

- (IBAction)valueChanged:(PINCodeTextField *)sender {
    [data setObject:sender.text forKey:sender.key];
    [self updateDoneButtonEnabledState];
}

#pragma mark - button actions

- (IBAction)done {
    
    // get data
    NSArray *keys = [data allKeys];
    NSArray *questionKeys = [[keys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF LIKE 'Question*'"]] 
                             sortedArrayUsingSelector:@selector(compare:)];
    NSArray *answerKeys = [[keys filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF LIKE 'Answer*'"]]
                           sortedArrayUsingSelector:@selector(compare:)];
    NSArray *questions = [data objectsForKeys:questionKeys notFoundMarker:[NSNull null]];
    NSArray *answers = [data objectsForKeys:answerKeys notFoundMarker:[NSNull null]];
    
    // do stuff with data
    objc_msgSend(self.delegate, self.action, self, questions, answers);
    
}

#pragma mark - table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.delegate numberOfSecurityQuestions];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TextFieldCell"];
    NSArray *subviews = cell.contentView.subviews;
    NSAssert([subviews count] == 1, @"There should only be one view in the cell content view");
    PINCodeTextField *field = [subviews lastObject];
    if (indexPath.row == 0) {
        field.autocorrectionType = UITextAutocorrectionTypeDefault;
        field.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        field.enabled = (self.mode != PINSecurityQuestionsViewControllerVerify);
        field.placeholder = @"Question";
        NSString *key = [NSString stringWithFormat:@"Question%ld", indexPath.section];
        field.key = key;
        field.text = [data objectForKey:key];
    }
    else if (indexPath.row == 1) {
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.enabled = YES;
        field.placeholder = @"Answer";
        field.key = [NSString stringWithFormat:@"Answer%ld", indexPath.section];
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"Question %ld", (section + 1)];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    CGFloat offset = 45.0;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(offset, 0.0, tableView.frame.size.width - offset, 35.0)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.font = [UIFont boldSystemFontOfSize:17.0];
    label.text = [self tableView:tableView titleForHeaderInSection:section];
    label.backgroundColor = [UIColor clearColor];
    label.opaque = YES;
    label.textColor = [UIColor whiteColor];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, tableView.frame.size.width, label.bounds.size.height)];
    [view addSubview:label];
    return view;
}

#pragma mark - private

- (void)updateDoneButtonEnabledState {
    BOOL __block enabled = YES;
    [[data allValues] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        enabled = (enabled && [obj length] > 0);
    }];
    enabled = enabled && [data count] == ([self.delegate numberOfSecurityQuestions] * 2);
    self.navigationItem.rightBarButtonItem.enabled = enabled;
}

@end
