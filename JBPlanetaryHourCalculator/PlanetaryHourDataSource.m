//
//  PlanetaryHourDataSource.m
//  JBPlanetaryHourCalculator
//
//  Created by Xcode Developer on 10/23/18.
//  Copyright © 2018 Xcode Developer. All rights reserved.
//

#import "PlanetaryHourDataSource.h"


@interface PlanetaryHourDataSource ()

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *lastLocation;

@end

@implementation PlanetaryHourDataSource

static PlanetaryHourDataSource *sharedDataSource = NULL;
+ (nonnull PlanetaryHourDataSource *)sharedDataSource
{
    static dispatch_once_t onceSecurePredicate;
    dispatch_once(&onceSecurePredicate,^
                  {
                      if (!sharedDataSource)
                          sharedDataSource = [[self alloc] init];
                  });
    
    return sharedDataSource;
}

static NSArray<NSString *> *_planetaryHourDataKeys = NULL;
+ (NSArray<NSString *> *)planetaryHourDataKeys {
    return @[kPlanetaryHourSymbolDataKey, kPlanetaryHourNameDataKey, kPlanetaryHourBeginDataKey, kPlanetaryHourEndDataKey, kPlanetaryHourLocationDataKey];
}

- (instancetype)init
{
    if (self == [super init])
    {
        self.planetaryHourDataRequestQueue = dispatch_queue_create_with_target("Planetary Hour Data Request Queue", DISPATCH_QUEUE_CONCURRENT, dispatch_get_main_queue());
        [[self locationManager] startMonitoringSignificantLocationChanges];
    }
    
    return self;
}

// Planetary Hours Dictionary methods
// (Create a dictionary of 24 planetary-hour dictionaries)





// The request and response blocks are separated from the cached data/cache data block
// so that multiple third-party data providers can be supported; distinct request and response blocks will be made for each service supported;
// if one returns nil, then another can be tried
NSArray *(^responseSunriseSunsetOrg)(NSData *) = ^(NSData *data) {
    __autoreleasing NSError *error;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    NSDateFormatter *RFC3339DateFormatter = [[NSDateFormatter alloc] init];
    RFC3339DateFormatter.locale = [NSLocale currentLocale];
    RFC3339DateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    RFC3339DateFormatter.timeZone = [NSTimeZone systemTimeZone];
    NSDate *sunrise = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"sunrise"]];
    NSDate *sunset  = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"sunset"]];
    NSArray *sunriseSunsetDates = @[sunrise, sunset];
    
    return sunriseSunsetDates;
};

NSURLRequest *(^requestSunriseSunsetOrg)(CLLocationCoordinate2D, NSDate *) = ^(CLLocationCoordinate2D coordinate, NSDate *date) {
    if (!date) date = [NSDate date];
    NSString *urlString = [NSString stringWithFormat:@"http://api.sunrise-sunset.org/json?lat=%f&lng=%f&date=%ld-%ld-%ld&formatted=0",
                           coordinate.latitude,
                           coordinate.longitude,
                           (long)[[NSCalendar currentCalendar] component:NSCalendarUnitYear fromDate:date],
                           (long)[[NSCalendar currentCalendar] component:NSCalendarUnitMonth fromDate:date],
                           (long)[[NSCalendar currentCalendar] component:NSCalendarUnitDay fromDate:date]];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:(NSTimeInterval)(10.0 * NSEC_PER_SEC)];
    
    return request;
};
//
//
//

// Get the requisite solar period data (sunrise and sunset times) either from the cache or from the source
// TO-DO: Add parameters for request and response blocks so that different sources can be used
void(^cachedSunriseSunsetData)(CLLocation * _Nullable, NSDate * _Nullable, CachedSunriseSunsetDataWithCompletionBlock) = ^(CLLocation * _Nullable location, NSDate * _Nullable date, CachedSunriseSunsetDataWithCompletionBlock sunriseSunsetData)
{
    NSURLRequest *request = requestSunriseSunsetOrg(location.coordinate, date);
    NSData *cachedData = [[[NSURLCache sharedURLCache] cachedResponseForRequest:request] data];
    if (cachedData) {
        sunriseSunsetData(responseSunriseSunsetOrg(cachedData));
    } else {
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error)
            {
                NSLog(@"Error getting response:\t%@", error);
            } else {
                NSDictionary *solarDataIdentifiers = @{@"location" : [NSString stringWithFormat:@"%f, %f", location.coordinate.latitude, location.coordinate.longitude], @"date" : date};
                NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data userInfo:solarDataIdentifiers storagePolicy:NSURLCacheStorageAllowed];
                [[NSURLCache sharedURLCache] storeCachedResponse:cachedResponse forRequest:request];
                NSData *cachedData = [[[NSURLCache sharedURLCache] cachedResponseForRequest:request] data];
                sunriseSunsetData(responseSunriseSunsetOrg(cachedData));
            }
        }] resume];
    }
};

Planet(^planetForDay)(NSDate *) = ^(NSDate *date)
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    long weekDay = (Day)[calendar component:NSCalendarUnitWeekday fromDate:date] - 1;
    weekDay = (weekDay < 0) ? 0 : weekDay;
    Planet planet = weekDay;
    
    return planet;
};

NSString *(^planetSymbolForHour)(NSDate *, NSUInteger) = ^(NSDate *date, NSUInteger hour)
{
    return planetSymbol((planetForDay(date) + hour) % 7);
};

NSString *(^planetNameForHour)(NSDate *, NSUInteger) = ^(NSDate *date, NSUInteger hour)
{
    return planetName((planetForDay(date) + hour) % 7);
};

NSDictionary *(^planetaryHourData)(NSArray<NSNumber *> *, NSUInteger, NSArray<NSDate *> *, CLLocationCoordinate2D) = ^(NSArray<NSNumber *> *hourDurations, NSUInteger hour, NSArray<NSDate *> *start, CLLocationCoordinate2D coordinate)
{
    NSUInteger index = (hour < HOURS_PER_SOLAR_TRANSIT) ? 0 : 1;
    NSTimeInterval startTimeInterval = hourDurations[index].doubleValue * hour;
    NSDate *startTime                = [[NSDate alloc] initWithTimeInterval:startTimeInterval sinceDate:start[index]];
    NSTimeInterval endTimeInterval   = hourDurations[index].doubleValue * (hour + 1);
    NSDate *endTime                  = [[NSDate alloc] initWithTimeInterval:endTimeInterval sinceDate:start[index]];
    
    NSDictionary *planetaryHour = @{kPlanetaryHourBeginDataKey    : [startTime description],
                                    kPlanetaryHourEndDataKey      : [endTime description],
                                    kPlanetaryHourLocationDataKey : [NSString stringWithFormat:@"%f, %f", coordinate.latitude, coordinate.longitude],
                                    kPlanetaryHourSymbolDataKey   : planetSymbolForHour(start[index], hour),
                                    kPlanetaryHourNameDataKey     : planetNameForHour(start[index], hour)};
    
    return planetaryHour;
};

- (void)planetaryHours:(_Nullable NSRangePointer *)hours date:(nullable NSDate *)date location:(nullable CLLocation *)location withCompletion:(void(^)(NSArray<NSDictionary *> *))planetaryHoursData;
{
    location = (CLLocationCoordinate2DIsValid(location.coordinate)) ? locationManager.location : location;
    cachedSunriseSunsetData(location, [NSDate date],
                            ^(NSArray<NSDate *> * _Nonnull sunriseSunsetDates) {
                                __block NSMutableArray<NSDictionary *> *planetaryHoursArray = [[NSMutableArray alloc] initWithCapacity:24];
                                __block dispatch_block_t planetaryHoursDictionaries;
                                
                                NSTimeInterval daySpan = [sunriseSunsetDates.firstObject timeIntervalSinceDate:sunriseSunsetDates.lastObject];
                                NSTimeInterval dayHourDuration = daySpan / HOURS_PER_SOLAR_TRANSIT;
                                NSTimeInterval nightSpan = fabs(SECONDS_PER_DAY - daySpan);
                                NSTimeInterval nightHourDuration = nightSpan / HOURS_PER_SOLAR_TRANSIT;
                                NSArray<NSNumber *> *hourDurations = @[[NSNumber numberWithDouble:dayHourDuration], [NSNumber numberWithDouble:nightHourDuration]];
                                
                                void(^planetaryHoursDictionary)(void) = ^(void) {
                                    [planetaryHoursArray addObject:planetaryHourData(hourDurations, planetaryHoursArray.count, sunriseSunsetDates, location.coordinate)];
                                    if (planetaryHoursArray.count < HOURS_PER_DAY) /*(sizeof(planetaryHoursArray) / sizeof([NSMutableArray class]))) */ planetaryHoursDictionaries();
                                    else planetaryHoursData(planetaryHoursArray);
                                };
                                
                                planetaryHoursDictionaries = ^{
                                    planetaryHoursDictionary();
                                };
                                planetaryHoursDictionaries();
                            });
    
}

- (void)planetaryHour:(NSUInteger)hour date:(nullable NSDate *)date location:(nullable CLLocation *)location withCompletion:(void(^)(NSDictionary *))planetaryHour;
{
    location = (CLLocationCoordinate2DIsValid(location.coordinate)) ? locationManager.location : location;
    cachedSunriseSunsetData(location, (!date) ? [NSDate date] : date,
                            ^(NSArray<NSDate *> * _Nonnull sunriseSunsetDates) {
                                NSTimeInterval daySpan = [sunriseSunsetDates.lastObject timeIntervalSinceDate:sunriseSunsetDates.firstObject];
                                NSTimeInterval dayHourDuration = daySpan / HOURS_PER_SOLAR_TRANSIT;
                                NSTimeInterval nightSpan = fabs(SECONDS_PER_DAY - daySpan);
                                NSTimeInterval nightHourDuration = nightSpan / HOURS_PER_SOLAR_TRANSIT;
                                NSLog(@"(%@\t-\t%@) / 12\t=\t%f", sunriseSunsetDates.firstObject, sunriseSunsetDates.lastObject, dayHourDuration);
                                
                                NSArray<NSNumber *> *hourDurations = @[[NSNumber numberWithDouble:dayHourDuration], [NSNumber numberWithDouble:nightHourDuration]];
                                planetaryHour(planetaryHourData(hourDurations, hour, sunriseSunsetDates, location.coordinate));
                            });
}

- (void)planetaryHour:(NSUInteger)hour date:(nullable NSDate *)date location:(nullable CLLocation *)location objectForKey:(PlanetaryHourDataKey)planetaryHourDataKey withCompletion:(void(^)(NSString *))planetaryHourDataObject;
{
    planetaryHourDataKey = planetaryHourDataKey % 5;
    [self planetaryHour:hour date:date location:location withCompletion:^(NSDictionary * _Nonnull planetaryHourData) {
        //        planetaryHourDataObject(planetaryHourData[planetaryHourDataKey]);
    }];
}

- (void)currentPlanetaryHourAtLocation:(nullable CLLocation *)location withCompletion:(void(^)(NSDictionary *))planetaryHourDataObject
{
    location = (CLLocationCoordinate2DIsValid(location.coordinate)) ? locationManager.location : location;
    cachedSunriseSunsetData(location, [NSDate date],
                            ^(NSArray<NSDate *> * _Nonnull sunriseSunsetDates) {
                                __block NSUInteger hour = 0;
                                __block dispatch_block_t planetaryHoursDictionaries;
                                
                                NSDateInterval *dateSpan = [[NSDateInterval alloc] initWithStartDate:sunriseSunsetDates.firstObject endDate:sunriseSunsetDates.lastObject];
                                NSTimeInterval dayHourDuration = dateSpan.duration / HOURS_PER_SOLAR_TRANSIT;
                                NSTimeInterval nightSpan = fabs(SECONDS_PER_DAY - dateSpan.duration);
                                NSTimeInterval nightHourDuration = nightSpan / HOURS_PER_SOLAR_TRANSIT;
                                NSArray<NSNumber *> *hourDurations = @[[NSNumber numberWithDouble:dayHourDuration], [NSNumber numberWithDouble:nightHourDuration]];
                                
                                void(^planetaryHoursDictionary)(NSInteger) = ^(NSInteger index) {
                                    NSTimeInterval startTimeInterval = hourDurations[index].doubleValue * hour;
                                    NSDate *startTime                = [[NSDate alloc] initWithTimeInterval:startTimeInterval sinceDate:sunriseSunsetDates[index]];
                                    NSTimeInterval endTimeInterval   = hourDurations[index].doubleValue * (hour + 1);
                                    NSDate *endTime                  = [[NSDate alloc] initWithTimeInterval:endTimeInterval sinceDate:sunriseSunsetDates[index]];
                                    
                                    NSDateInterval *dateInterval = [[NSDateInterval alloc] initWithStartDate:startTime endDate:endTime];
                                    if (![dateInterval containsDate:[NSDate date]])
                                    {
                                        hour++;
                                        planetaryHoursDictionaries();
                                    } else {
                                        planetaryHourDataObject(planetaryHourData(hourDurations, hour, sunriseSunsetDates, location.coordinate));
                                    }
                                };
                                
                                planetaryHoursDictionaries = ^{
                                    planetaryHoursDictionary((hour < HOURS_PER_SOLAR_TRANSIT) ? 0 : 1);
                                };
                                planetaryHoursDictionaries();
                            });
}

#pragma mark - EventKit

typedef void(^CalendarForEventStoreCompletionBlock)(EKCalendar *calendar);
typedef void(^CalendarForEventStore)(EKEventStore *eventStore, CalendarForEventStoreCompletionBlock completionBlock);
void(^calendarForEventStore)(EKEventStore *, CalendarForEventStoreCompletionBlock) = ^(EKEventStore *eventStore, CalendarForEventStoreCompletionBlock completionBlock)
{
    printf("\n%s\n", __PRETTY_FUNCTION__);
    
    NSArray <EKCalendar *> *calendars = [eventStore calendarsForEntityType:EKEntityTypeEvent];
    [calendars enumerateObjectsUsingBlock:^(EKCalendar * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.title isEqualToString:@"Planetary Hour"]) {
            NSLog(@"Planetary Hour calendar found.");
            completionBlock(obj);
            *stop = TRUE;
        } else if (calendars.count == (idx + 1))
        {
            EKCalendar *calendar = [EKCalendar calendarForEntityType:EKEntityTypeEvent eventStore:eventStore];
            calendar.title = @"Planetary Hour";
            calendar.source = eventStore.sources[1];
            __autoreleasing NSError *error;
            if ([eventStore saveCalendar:calendar commit:YES error:&error])
            {
                completionBlock(calendar);
            } else {
                NSLog(@"Error saving new calendar: %@\nUsing default calendar for new events...", error.localizedDescription);
                completionBlock([eventStore defaultCalendarForNewEvents]);
            }
        }
    }];
};

//NSPredicate *predicate = [sut predicateForEventsWithStartDate:startDate endDate:endDate calendars:nil];
//
//NSArray *events = [sut eventsMatchingPredicate:predicate];
//
//if (events && events.count > 0) {
//
//    NSLog(@"Deleting Events...");
//
//    [events enumerateObjectsUsingBlock:^(EKEvent *event, NSUInteger idx, BOOL *stop) {
//
//        NSLog(@"Removing Event: %@", event);
//        NSError *error;
//        if ( ! [sut removeEvent:event span:EKSpanFutureEvents commit:NO error:&error]) {
//
//            NSLog(@"Error in delete: %@", error);
//
//        }
//
//    }];
//
//    [sut commit:NULL];
//
//} else {
//
//    NSLog(@"No Events to Delete.");
//}

//        solarTransitPeriodData(solarTransitPeriodDataURL(currentLocation), ^(NSArray <NSDate *> *dates) {
//            [self.delegate createEventWithDateSpan:dates location:currentLocation completion:^{
//                self.lastLocation = nil;
//            }];
//        });

- (void)createEventWithDateSpan:(NSArray <NSDate *> *)dates location:(CLLocation *)location completion:(void (^)(void))completionBlock
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSDateInterval *dateSpan = [[NSDateInterval alloc] initWithStartDate:dates.firstObject endDate:dates.lastObject];
    NSTimeInterval dayDuration = dateSpan.duration / 12.0;
    NSTimeInterval nightSpan = fabs(86400.0 - dayDuration);
    NSTimeInterval nightDuration = nightSpan / 12.0;
    
    //    Create an EKEventStore instance
    EKEventStore *eventStore = [[EKEventStore alloc] init];
    [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
        if (granted)
        {
            calendarForEventStore(eventStore, ^(EKCalendar *calendar) {
                //                EKEvent *event = [EKEvent eventWithEventStore:eventStore];
                //                event.calendar = calendar;
                //                event.title = [NSString stringWithFormat:@"%@ Solar Transit Period", meridian(dates.firstObject)];
                //                event.location = [NSString stringWithFormat:@"%f, %f", location.coordinate.latitude, location.coordinate.longitude];
                //                event.startDate = dates.firstObject;
                //                event.endDate = dates.lastObject;
                //                event.allDay = NO;
                //
                //                __autoreleasing NSError *error;
                //                if ([eventStore saveEvent:event span:EKSpanThisEvent error:&error])
                //                {
                //                    NSLog(@"Event saved.");
                //                } else {
                //                    NSLog(@"Error saving event: %@", error.description);
                //                }
                
                __block Planet planet = planetForDay(dates.firstObject);
               for (long hourMultiplier = 0; hourMultiplier < 12; hourMultiplier++)
                {
                    NSTimeInterval startTimeInterval = dayDuration * hourMultiplier; //(hourMultiplier < 12) ? dayDuration * hourMultiplier : nightDuration * hourMultiplier; //(solarPeriod == AM) ? dayDuration * hourMultiplier : nightDuration * hourMultiplier;
                    NSDate *startTime                = [[NSDate alloc] initWithTimeInterval:startTimeInterval sinceDate:dates.firstObject]; //(solarPeriod == AM) ? dates.firstObject : dates.lastObject];
                    NSTimeInterval endTimeInterval   = dayDuration * (hourMultiplier + 1); //(hourMultiplier < 12) ? dayDuration * (hourMultiplier + 1) : nightDuration * (hourMultiplier + 1); //(solarPeriod == AM) ? dayDuration * (hourMultiplier + 1) : nightDuration * (hourMultiplier + 1);
                    NSDate *endTime                  = [[NSDate alloc] initWithTimeInterval:endTimeInterval sinceDate:dates.firstObject];
                    
                    EKEvent *event  = [EKEvent eventWithEventStore:eventStore];
                    event.calendar  = calendar;
                    event.title     = [NSString stringWithFormat:@"%@\t%@", planetSymbol((planet + hourMultiplier) % 7), planetName((planet + hourMultiplier) % 7)];
                    event.location  = [NSString stringWithFormat:@"%f, %f", location.coordinate.latitude, location.coordinate.longitude];
                    event.notes     = [NSString stringWithFormat:@"%@\t%@", planetSymbol((planet + hourMultiplier) % 7), planetName((planet + hourMultiplier) % 7)];
                    event.startDate = startTime;    //(hourMultiplier == 0)  ? dates.firstObject : startTime;
                    event.endDate   = endTime;      //(hourMultiplier == 11) ? dates.lastObject  : endTime;
                    event.allDay    = NO;
                    __autoreleasing NSError *error;
                    if ([eventStore saveEvent:event span:EKSpanThisEvent error:&error])
                    {
                        NSLog(@"Event %lu saved.", (hourMultiplier + 1));
                    } else {
                        NSLog(@"Error saving event: %@", error.description);
                    }
                }
                
                for (long hourMultiplier = 0; hourMultiplier < 12; hourMultiplier++)
                {
                    NSTimeInterval startTimeInterval = nightDuration * hourMultiplier; //(hourMultiplier < 12) ? dayDuration * hourMultiplier : nightDuration * hourMultiplier; //(solarPeriod == AM) ? dayDuration * hourMultiplier : nightDuration * hourMultiplier;
                    NSDate *startTime                = [[NSDate alloc] initWithTimeInterval:startTimeInterval sinceDate:dates.lastObject]; //(solarPeriod == AM) ? dates.firstObject : dates.lastObject];
                    NSTimeInterval endTimeInterval   = nightDuration * (hourMultiplier + 1); //(hourMultiplier < 12) ? dayDuration * (hourMultiplier + 1) : nightDuration * (hourMultiplier + 1); //(solarPeriod == AM) ? dayDuration * (hourMultiplier + 1) : nightDuration * (hourMultiplier + 1);
                    NSDate *endTime                  = [[NSDate alloc] initWithTimeInterval:endTimeInterval sinceDate:dates.lastObject];
                    
                    EKEvent *event  = [EKEvent eventWithEventStore:eventStore];
                    event.calendar  = calendar;
                    event.title     = [NSString stringWithFormat:@"%@\t%@", planetSymbol((planet + hourMultiplier) % 7), planetName((planet + hourMultiplier) % 7)];
                    event.location  = [NSString stringWithFormat:@"%f, %f", location.coordinate.latitude, location.coordinate.longitude];
                    event.notes     = [NSString stringWithFormat:@"%@\t%@", planetSymbol((planet + hourMultiplier) % 7), planetName((planet + hourMultiplier) % 7)];
                    event.startDate = startTime;    //(hourMultiplier == 0)  ? dates.firstObject : startTime;
                    event.endDate   = endTime;      //(hourMultiplier == 11) ? dates.lastObject  : endTime;
                    event.allDay    = NO;
                    __autoreleasing NSError *error;
                    if ([eventStore saveEvent:event span:EKSpanThisEvent error:&error])
                    {
                        NSLog(@"Event %lu saved.", (hourMultiplier + 1));
                    } else {
                        NSLog(@"Error saving event: %@", error.description);
                    }
                }
                //                }
            });
        } else {
            NSLog(@"Access to event store denied: %@", error.description);
        }
        completionBlock();
    }];
}


#pragma mark - Location Services

static CLLocationManager *locationManager = NULL;
- (CLLocationManager *)locationManager
{
    static dispatch_once_t onceSecurePredicate;
    dispatch_once(&onceSecurePredicate,^
                  {
                      if (!locationManager)
                      {
                          locationManager = [[CLLocationManager alloc] init];
                          if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
                              [locationManager requestWhenInUseAuthorization];
                          }
                          locationManager.pausesLocationUpdatesAutomatically = TRUE;
                          [locationManager setDelegate:(id<CLLocationManagerDelegate> _Nullable)self];
                      }
                  });
    
    return locationManager;
}

#pragma mark <CLLocationManagerDelegate methods>

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"%s\n%@", __PRETTY_FUNCTION__, error.localizedDescription);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSLog(@"%s\t\t\nLocation services authorization status code:\t%d", __PRETTY_FUNCTION__, status);
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted)
    {
        NSLog(@"%s\nFailure to authorize location services", __PRETTY_FUNCTION__);
    }
    else
    {
        CLAuthorizationStatus authStatus = [CLLocationManager authorizationStatus];
        if (authStatus == kCLAuthorizationStatusAuthorizedWhenInUse ||
            authStatus == kCLAuthorizationStatusAuthorizedAlways)
        {
            NSLog(@"Location services authorized");
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CLLocation *currentLocation = [locations lastObject];
    if ((self.lastLocation == nil) || (((self.lastLocation.coordinate.latitude != currentLocation.coordinate.latitude) || (self.lastLocation.coordinate.longitude != currentLocation.coordinate.longitude)) && ((currentLocation.coordinate.latitude != 0.0) || (currentLocation.coordinate.longitude != 0.0)))) {
        self.lastLocation = [[CLLocation alloc] initWithLatitude:currentLocation.coordinate.latitude longitude:currentLocation.coordinate.longitude];
        NSLog(@"%s", __PRETTY_FUNCTION__);
        //    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlanetaryHoursDataSourceUpdatedNotification"
        //                                                        object:nil
        //                                                      userInfo:nil];
    }
}

- (void)dealloc
{
    [locationManager stopMonitoringSignificantLocationChanges];
}

@end

//
//NSArray *(^datesWithData)(NSData *) = ^(NSData *urlSessionData)
//{
//    printf("%s\n", __PRETTY_FUNCTION__);
//
//    // Create midnight date object for current day
//    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
//    NSString *midnightDateString = [NSString stringWithFormat:@"%lu-%lu-%lu'T'00:00:00+00:00",
//                                    (long)[calendar component:NSCalendarUnitYear fromDate:[NSDate date]],
//                                    (long)[calendar component:NSCalendarUnitMonth fromDate:[NSDate date]],
//                                    (long)[calendar component:NSCalendarUnitDay fromDate:[NSDate date]]];
//
//
//    __autoreleasing NSError *error;
//    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:urlSessionData options:NSJSONReadingMutableLeaves error:&error];
//    NSDateFormatter *RFC3339DateFormatter = [[NSDateFormatter alloc] init];
//    RFC3339DateFormatter.locale = [NSLocale currentLocale];
//    RFC3339DateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
//    RFC3339DateFormatter.timeZone = [NSTimeZone localTimeZone];
//    NSDate *midnight = [RFC3339DateFormatter dateFromString:midnightDateString];
//    NSDate *sunrise = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"sunrise"]];
//    NSDate *sunset  = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"sunset"]];
//    NSDate *solarNoon  = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"solar_noon"]];
//    NSDate *civilTwilightBegin  = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"civil_twilight_begin"]];
//    NSDate *civilTwilightEnd  = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"civil_twilight_end"]];
//    NSDate *nauticalTwilightBegin  = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"nautical_twilight_begin"]];
//    NSDate *nauticalTwilightEnd  = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"nautical_twilight_end"]];
//    NSDate *astronomicalTwilightBegin  = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"astronomical_twilight_begin"]];
//    NSDate *astronomicalTwlightEnd  = [RFC3339DateFormatter dateFromString:[[responseDict objectForKey:@"results"] objectForKey:@"astronomical_twilight_end"]];
//
//    return @[midnight, astronomicalTwilightBegin, nauticalTwilightBegin, civilTwilightBegin, sunrise, solarNoon, sunset, civilTwilightEnd, nauticalTwilightEnd, astronomicalTwlightEnd];
//};

