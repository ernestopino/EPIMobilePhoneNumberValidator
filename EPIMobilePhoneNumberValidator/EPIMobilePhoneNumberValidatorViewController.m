//
//  EPIMobilePhoneNumberValidatorViewController.m
//  EPIMobilePhoneNumberValidator
//
//  Created by Ernesto Pino on 25/2/16.
//  Copyright © 2016 EPINOM. All rights reserved.
//

#import "EPIMobilePhoneNumberValidatorViewController.h"

#import "NBPhoneNumberUtil.h"
#import "NBAsYouTypeFormatter.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "EPICountry.h"

#define kE164MaximumPhoneLenght        14
#define kPhoneCodeCornerRadius         5
#define kPhoneCodeBorderWidth          1.5
#define kKeyboardAnimationDuration     0.2
#define kPhoneNumberPlaceholder        @"#"
#define kE164CountryCodesFileName      @"country-codes"
#define kE164CountryCodesFileExtension @"json"
#define kISOSupportedCountries         @[@"ES", @"US", @"GB"]

@interface EPIMobilePhoneNumberValidatorViewController () <UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate>

@property (weak, nonatomic) IBOutlet UITextField *countryTextField;
@property (weak, nonatomic) IBOutlet UILabel *phoneCodeLabel;
@property (weak, nonatomic) IBOutlet UILabel *countryLabel;
@property (weak, nonatomic) IBOutlet UIButton *countrySelectorButton;
@property (weak, nonatomic) IBOutlet UIImageView *selectorImageView;
@property (weak, nonatomic) IBOutlet UITextField *phoneNumberTextField;
@property (weak, nonatomic) IBOutlet UILabel *displayLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *keyboardConstraint;

// Style
@property (strong, nonatomic) UIColor *activeTextColor;
@property (strong, nonatomic) UIColor *validTextColor;
@property (strong, nonatomic) UIColor *invalidTextColor;
@property (strong, nonatomic) UIColor *placeholderTextColor;
@property (strong, nonatomic) NBAsYouTypeFormatter *asYouTypeFormatter;

// Validation
@property (strong, nonatomic) NSString *currentInputPhoneString;
@property (strong, nonatomic) EPICountry *currentCountry;
@property (assign, nonatomic) BOOL isCountrySelectorActive;
@property (assign, nonatomic) BOOL mutexCountrySelector;
@property (assign, nonatomic) NSInteger currentCountryPickerSelectedIndex;
@property (assign, nonatomic) BOOL validationSuccess;
@property (strong, nonatomic) NSArray *supportedISOCountryCodes;
@property (strong, nonatomic) NSMutableDictionary *supportedCountries;
@property (strong, nonatomic) NSArray *supportedCountryKeys;
@property (assign, nonatomic) CGFloat keyboardHeight;

@end

@implementation EPIMobilePhoneNumberValidatorViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Initialize supported countries
    self.supportedISOCountryCodes = kISOSupportedCountries;
    
    // Listen for keyboard appearances and disappearances
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    // Validation bar button item
    UIBarButtonItem *sendBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStylePlain target:self action:@selector(sendBarButtonItemAction:)];
    self.navigationItem.rightBarButtonItem = sendBarButtonItem;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    // Configure textfield
    self.phoneNumberTextField.delegate = self;
    self.phoneNumberTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.phoneNumberTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.phoneNumberTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kKeyboardAnimationDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.phoneNumberTextField becomeFirstResponder];
    });
    
    // Setup
    [self setup];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"validationSuccess"])
    {
        BOOL isPhoneValid = [[change objectForKey: NSKeyValueChangeNewKey] boolValue];
        self.navigationItem.rightBarButtonItem.enabled = isPhoneValid;
    }
}

#pragma mark - Keyboard notifications

- (void)keyboardDidShow:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    double animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:animationDuration animations:^{
        self.keyboardConstraint.constant = kbSize.height;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)keyboardDidHide:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    double animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:animationDuration animations:^{
        self.keyboardConstraint.constant = 0;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (self.validationSuccess)
        {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert" message:@"Great !!! \nAction executed." preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *alertAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self.phoneNumberTextField becomeFirstResponder];
            }];
            [alertController addAction:alertAction];
            [self presentViewController:alertController animated:YES completion:nil];
        }
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *phoneNumber;
    BOOL validinput = NO;
    
    if(self.phoneNumberTextField.text.length + string.length <= kE164MaximumPhoneLenght)
    {
        // Something entered by user
        if(range.length == 0)
        {
            phoneNumber = [self.asYouTypeFormatter inputDigit:string];
            self.displayLabel.text = phoneNumber;
            self.currentInputPhoneString = [NSString stringWithFormat:@"%@%@", textField.text, string];
        }
        else if(range.length == 1)  // Backspace
        {
            phoneNumber = [self.asYouTypeFormatter removeLastDigit];
            self.displayLabel.text = phoneNumber;
            self.currentInputPhoneString = [self.currentInputPhoneString substringToIndex:self.currentInputPhoneString.length - 1];
        }
        
        validinput = YES;
    }
    
    // Update view
    [self updateView];
    
    // Logs
    [self traceToConsole];
    
    return validinput;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
}

#pragma mark - UIPickerViewDataSource

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    NSString *isoCodeKey = (NSString *) self.supportedCountryKeys[row];
    EPICountry *country = (EPICountry *) [self.supportedCountries objectForKey:isoCodeKey];
    NSString *titleForRow = [NSString stringWithFormat:@"(+%@) %@", country.phoneCode, country.name];
    return titleForRow;
}


#pragma mark - UIPickerViewDelegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    // Update selected index
    self.currentCountryPickerSelectedIndex = row;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.supportedCountryKeys.count;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

#pragma mark - Actions

- (void)sendBarButtonItemAction:(id)sender
{
    [self.phoneNumberTextField resignFirstResponder];
}

- (IBAction)countrySelectorAction:(id)sender
{
    if (self.mutexCountrySelector == NO)
    {
        // Take the mutex
        self.mutexCountrySelector = YES;
        
        // Check selector state
        if (self.isCountrySelectorActive == NO)
        {
            // Activate selector
            [self.countryTextField becomeFirstResponder];
            
            // Animate selector indicator
            [UIView animateWithDuration:0.5 animations:^{
                // Flip image vertical
                self.selectorImageView.layer.transform = CATransform3DMakeRotation(M_PI,1.0,0.0,0.0);
            } completion:^(BOOL finished) {
                // Update flag
                self.isCountrySelectorActive = YES;
                // Release the mutex
                self.mutexCountrySelector = NO;
            }];
        }
        else
        {
            // Deactivate selector and activate phone number textfield
            [self updateViewForCountrySelection];
            [self.phoneNumberTextField becomeFirstResponder];
            
            // Animate selector indicator
            [UIView animateWithDuration:0.5 animations:^{
                // Flip image vertical
                self.selectorImageView.layer.transform = CATransform3DMakeRotation(0,1.0,0.0,0.0);
            } completion:^(BOOL finished) {
                // Update flag
                self.isCountrySelectorActive = NO;
                // Release the mutex
                self.mutexCountrySelector = NO;
            }];
        }
    }
}

#pragma mark - Helper methods

- (void)updateView
{
    // Update selector with current values
    self.phoneCodeLabel.text = [NSString stringWithFormat:@"+%@", self.currentCountry.phoneCode];
    self.countryLabel.text = self.currentCountry.name;
    
    // Display text in placeholder
    if (self.displayLabel.text == nil || [self.displayLabel.text isEqualToString:@""])
    {
        self.displayLabel.textColor = self.placeholderTextColor;
        self.displayLabel.text = kPhoneNumberPlaceholder;
    }
    else if (self.displayLabel.text != nil &&
             ![self.displayLabel.text isEqualToString:@""] &&   // Text color are active
             self.currentInputPhoneString.length > 0)
    {
        NBPhoneNumberUtil *phoneUtil = [[NBPhoneNumberUtil alloc] init];
        NSError *error = nil;
        NBPhoneNumber *phoneNumber = [phoneUtil parse:self.currentInputPhoneString defaultRegion:self.currentCountry.isoCode error:&error];
        
        self.displayLabel.textColor = [phoneUtil isPossibleNumber:phoneNumber error:nil] ? self.activeTextColor : self.invalidTextColor;
        BOOL isMobilePhone = [phoneUtil isValidNumber:phoneNumber] && ([phoneUtil getNumberType:phoneNumber] == NBEPhoneNumberTypeMOBILE || [phoneUtil getNumberType:phoneNumber] == NBEPhoneNumberTypeFIXED_LINE_OR_MOBILE);
        if (isMobilePhone) self.displayLabel.textColor = self.validTextColor;
        self.validationSuccess = isMobilePhone;
    }
}

- (void)setup
{
    // KVOs
    [self addObserver:self forKeyPath:@"validationSuccess" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];
    
    // Text colors
    self.placeholderTextColor = [UIColor lightGrayColor];
    self.activeTextColor = [UIColor blackColor];
    self.validTextColor = [UIColor greenColor];
    self.invalidTextColor = [UIColor redColor];
    
    // Styles
    self.phoneCodeLabel.backgroundColor = [UIColor clearColor];
    self.phoneCodeLabel.layer.cornerRadius = kPhoneCodeCornerRadius;
    self.phoneCodeLabel.layer.masksToBounds = YES;
    self.phoneCodeLabel.layer.borderColor = [UIColor blackColor].CGColor;
    self.phoneCodeLabel.layer.borderWidth = kPhoneCodeBorderWidth;
    
    // Clean display text
    self.displayLabel.text = @"";
    
    // Hide input text
    self.phoneNumberTextField.hidden = YES;
    self.countryTextField.hidden = YES;
    
    // Country picker
    UIPickerView *countryPickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 216)];
    countryPickerView.dataSource = self;
    countryPickerView.delegate = self;
    countryPickerView.showsSelectionIndicator = YES;
    
    // Input views
    self.countryTextField.inputView = countryPickerView;
    
    // Get countries info
    NSLocale *locale = [NSLocale currentLocale];
    NSArray *isoCountryCodes = [NSLocale ISOCountryCodes];
    NSMutableArray *countryNames = [[NSMutableArray alloc] init];
    for (NSString *countryCode in isoCountryCodes) {
        NSString *countryName = [locale displayNameForKey:NSLocaleCountryCode value:countryCode];
        [countryNames addObject:countryName];
    }
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:kE164CountryCodesFileName ofType:kE164CountryCodesFileExtension];
    NSString *e164countryCodesString = [[NSString alloc] initWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *e164countryCodesJSON = [NSJSONSerialization JSONObjectWithData:[e164countryCodesString dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    
    // Create objects for supported countries
    self.supportedCountries = [NSMutableDictionary new];
    NSString *currentCountryCode = [locale objectForKey: NSLocaleCountryCode];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF IN %@", self.supportedISOCountryCodes];
    for (NSUInteger i = 0; i < isoCountryCodes.count; i++) {
        NSString *countryCode = (NSString *) [isoCountryCodes objectAtIndex:i];
        BOOL isSupportedCountry = [predicate evaluateWithObject:countryCode];
        if (isSupportedCountry)
        {
            // Supported country
            EPICountry *country = [EPICountry new];
            country.isoCode = countryCode;
            country.name = (NSString *) [countryNames objectAtIndex:i];
            country.phoneCode = (NSString *) [e164countryCodesJSON objectForKey:countryCode];
            
            // Add country to supported dictionary
            [self.supportedCountries setValue:country forKey:country.isoCode];
            
            // Check for current country
            if ([country.isoCode isEqualToString:currentCountryCode])
                self.currentCountry = country;
        }
    }
    
    // Obtain all keys for supported countries, sorted by localized comparator
    NSMutableArray *sortedSupportedCountryKeys = [[NSMutableArray alloc] initWithArray:[self.supportedCountries allKeys]];
    [sortedSupportedCountryKeys sortUsingSelector:@selector(localizedCompare:)];
    self.supportedCountryKeys = [sortedSupportedCountryKeys copy];
    
    // Disable country selector if only have one country
    if (self.supportedCountries != nil && self.supportedCountries.count <= 1) {
        self.selectorImageView.hidden = YES;
        self.countrySelectorButton.enabled = NO;
    }
    
    // Check if we have a current country
    if (!self.currentCountry) {
        NSString *firstISOCode = (NSString *) [self.supportedCountryKeys firstObject];
        self.currentCountry = [self.supportedCountries objectForKey:firstISOCode];
    }
    
    // Create validator with current ISO country code
    self.asYouTypeFormatter = [[NBAsYouTypeFormatter alloc] initWithRegionCode:self.currentCountry.isoCode];
    
    // Update
    [self updateView];
}

- (void)updateViewForCountrySelection
{
    NSString *isoCodeKey = (NSString *) self.supportedCountryKeys[self.currentCountryPickerSelectedIndex];
    EPICountry *country = (EPICountry *) [self.supportedCountries objectForKey:isoCodeKey];
    NSLog(@"Selected country: %@ - %@ - %@", country.isoCode, country.name, country.phoneCode);
    
    // Change phone formatter if proceed
    if (![country.isoCode isEqualToString:self.currentCountry.isoCode]) {
        
        // Update formatter
        self.asYouTypeFormatter = [[NBAsYouTypeFormatter alloc] initWithRegionCode:country.isoCode];
        
        // Update current selected country
        self.currentCountry = country;
        
        // Reset previous phone
        self.phoneNumberTextField.text = @"";
        self.displayLabel.text = @"";
        
        // Update labels
        self.phoneCodeLabel.text = [NSString stringWithFormat:@"+%@", country.phoneCode];
        self.countryLabel.text = country.name;
        
        // Update view
        [self updateView];
    }
}

- (void)traceToConsole
{
    NSLog(@"\n---------------------------");
    NSLog(@"Texfield before: %@", self.phoneNumberTextField.text);
    NSLog(@"Phone number: %@", self.currentInputPhoneString);
    NSLog(@"Display: %@", self.displayLabel.text);
    
    NBPhoneNumberUtil *phoneUtil = [[NBPhoneNumberUtil alloc] init];
    NSError *anError = nil;
    NBPhoneNumber *myNumber = [phoneUtil parse:self.displayLabel.text defaultRegion:self.currentCountry.isoCode error:&anError];
    NSLog(@"Is possible phone number?: %@", [phoneUtil isPossibleNumber:myNumber error:nil] ? @"YES":@"NO");
    NSLog(@"Valid phone number?: %@", [phoneUtil isValidNumber:myNumber] ? @"YES":@"NO");
    NSLog(@"Phone number type (0. FIXED_LINE 1. MOBILE 2. FIXED_LINE_OR_MOBILE : %ld", (long)[phoneUtil getNumberType:myNumber]);
}

@end
