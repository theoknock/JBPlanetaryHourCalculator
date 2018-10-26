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

#pragma mark - EventStore

static EKEventStore *eventStore = NULL;
+ (nonnull EKEventStore *)eventStore
{
    static dispatch_once_t onceSecurePredicate;
    dispatch_once(&onceSecurePredicate,^
                  {
                      if (!eventStore)
                      {
                          eventStore = [[EKEventStore alloc] init];
                      }
                  });
    
    return eventStore;
}

- (void)dealloc
{
    [locationManager stopMonitoringSignificantLocationChanges];
}

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

NSArray<NSNumber *> *(^hourDurations)(NSDateInterval *) = ^(NSDateInterval *dateSpan)
{
    NSTimeInterval dayDuration = dateSpan.duration / HOURS_PER_SOLAR_TRANSIT;
    NSTimeInterval nightSpan = fabs(SECONDS_PER_DAY - dayDuration);
    NSTimeInterval nightDuration = nightSpan / HOURS_PER_SOLAR_TRANSIT;
    NSArray<NSNumber *> *hourDurations = @[[NSNumber numberWithDouble:dayDuration], [NSNumber numberWithDouble:nightDuration]];
    
    return hourDurations;
};

void(^cachedSunriseSunsetData)(CLLocation * _Nullable, NSDate * _Nullable, CachedSunriseSunsetDataWithCompletionBlock) = ^(CLLocation * _Nullable location, NSDate * _Nullable date, CachedSunriseSunsetDataWithCompletionBlock sunriseSunsetData)
{
    NSURLRequest *request = requestSunriseSunsetOrg(location.coordinate, date);
    NSData *cachedData = [[[NSURLCache sharedURLCache] cachedResponseForRequest:request] data];
    if (cachedData) {
        NSArray<NSDate *> *sunriseSunsetDates = responseSunriseSunsetOrg(cachedData);
        NSDateInterval *dateSpan = [[NSDateInterval alloc] initWithStartDate:sunriseSunsetDates.firstObject endDate:sunriseSunsetDates.lastObject];
        sunriseSunsetData(sunriseSunsetDates, hourDurations(dateSpan));
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
                NSArray<NSDate *> *sunriseSunsetDates = responseSunriseSunsetOrg(cachedData);
                NSDateInterval *dateSpan = [[NSDateInterval alloc] initWithStartDate:sunriseSunsetDates.firstObject endDate:sunriseSunsetDates.lastObject];
                sunriseSunsetData(sunriseSunsetDates, hourDurations(dateSpan));
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

NSString *(^planetSymbolForHour)(Planet, NSUInteger) = ^(Planet planetForDay, NSUInteger hour)
{
    return planetSymbol((planetForDay + hour) % 7);
};

NSString *(^planetNameForHour)(Planet, NSUInteger) = ^(Planet planetForDay, NSUInteger hour)
{
    return planetName((planetForDay + hour) % 7);
};

//NSDictionary *(^planetaryHourData)(NSArray<NSNumber *> *, NSUInteger, NSArray<NSDate *> *, CLLocationCoordinate2D) = ^(NSArray<NSNumber *> *hourDurations, NSUInteger hour, NSArray<NSDate *> *dates, CLLocationCoordinate2D coordinate)
//{
//    NSUInteger index = (hour < HOURS_PER_SOLAR_TRANSIT) ? 0 : 1;
//    NSTimeInterval startTimeInterval = hourDurations[index].doubleValue * hour;
//    NSDate *startTime                = [[NSDate alloc] initWithTimeInterval:startTimeInterval sinceDate:dates[index]];
//    NSTimeInterval endTimeInterval   = hourDurations[index].doubleValue * (hour + 1);
//    NSDate *endTime                  = [[NSDate alloc] initWithTimeInterval:endTimeInterval sinceDate:dates[index]];
//    Planet dailyPlanet               = planetForDay(dates[index]);
//    NSDictionary *planetaryHour      = @{kPlanetaryHourBeginDataKey    : [startTime description],
//                                         kPlanetaryHourEndDataKey      : [endTime description],
//                                         kPlanetaryHourLocationDataKey : [NSString stringWithFormat:@"%f, %f", coordinate.latitude, coordinate.longitude],
//                                         kPlanetaryHourSymbolDataKey   : planetSymbolForHour(dailyPlanet, hour),
//                                         kPlanetaryHourNameDataKey     : planetNameForHour(dailyPlanet, hour)};
//
//    return planetaryHour;
//};

//- (void)planetaryHours:(_Nullable NSRangePointer *)hours date:(nullable NSDate *)date location:(nullable CLLocation *)location withCompletion:(void(^)(NSArray<NSDictionary *> *))planetaryHoursData;
//{
//    location = (CLLocationCoordinate2DIsValid(location.coordinate)) ? locationManager.location : location;
//    cachedSunriseSunsetData(location, [NSDate date],
//                            ^(NSArray<NSDate *> * _Nonnull sunriseSunsetDates) {
//                                __block NSMutableArray<NSDictionary *> *planetaryHoursArray = [[NSMutableArray alloc] initWithCapacity:24];
//                                __block dispatch_block_t planetaryHoursDictionaries;
//
//                                NSTimeInterval daySpan = [sunriseSunsetDates.firstObject timeIntervalSinceDate:sunriseSunsetDates.lastObject];
//                                NSTimeInterval dayHourDuration = daySpan / HOURS_PER_SOLAR_TRANSIT;
//                                NSTimeInterval nightSpan = fabs(SECONDS_PER_DAY - daySpan);
//                                NSTimeInterval nightHourDuration = nightSpan / HOURS_PER_SOLAR_TRANSIT;
//                                NSArray<NSNumber *> *hourDurations = @[[NSNumber numberWithDouble:dayHourDuration], [NSNumber numberWithDouble:nightHourDuration]];
//
//                                void(^planetaryHoursDictionary)(void) = ^(void) {
//                                    [planetaryHoursArray addObject:planetaryHourData(hourDurations, planetaryHoursArray.count, sunriseSunsetDates, location.coordinate)];
//                                    if (planetaryHoursArray.count < HOURS_PER_DAY) /*(sizeof(planetaryHoursArray) / sizeof([NSMutableArray class]))) */ planetaryHoursDictionaries();
//                                    else planetaryHoursData(planetaryHoursArray);
//                                };
//
//                                planetaryHoursDictionaries = ^{
//                                    planetaryHoursDictionary();
//                                };
//                                planetaryHoursDictionaries();
//                            });
//
//}
//
//- (void)planetaryHour:(NSUInteger)hour date:(nullable NSDate *)date location:(nullable CLLocation *)location withCompletion:(void(^)(NSDictionary *))planetaryHour;
//{
//    location = (CLLocationCoordinate2DIsValid(location.coordinate)) ? locationManager.location : location;
//    cachedSunriseSunsetData(location, (!date) ? [NSDate date] : date,
//                            ^(NSArray<NSDate *> * _Nonnull sunriseSunsetDates) {
//                                NSTimeInterval daySpan = [sunriseSunsetDates.lastObject timeIntervalSinceDate:sunriseSunsetDates.firstObject];
//                                NSTimeInterval dayHourDuration = daySpan / HOURS_PER_SOLAR_TRANSIT;
//                                NSTimeInterval nightSpan = fabs(SECONDS_PER_DAY - daySpan);
//                                NSTimeInterval nightHourDuration = nightSpan / HOURS_PER_SOLAR_TRANSIT;
//                                NSLog(@"(%@\t-\t%@) / 12\t=\t%f", sunriseSunsetDates.firstObject, sunriseSunsetDates.lastObject, dayHourDuration);
//
//                                NSArray<NSNumber *> *hourDurations = @[[NSNumber numberWithDouble:dayHourDuration], [NSNumber numberWithDouble:nightHourDuration]];
//                                planetaryHour(planetaryHourData(hourDurations, hour, sunriseSunsetDates, location.coordinate));
//                            });
//}
//
//- (void)planetaryHour:(NSUInteger)hour date:(nullable NSDate *)date location:(nullable CLLocation *)location objectForKey:(PlanetaryHourDataKey)planetaryHourDataKey withCompletion:(void(^)(NSString *))planetaryHourDataObject;
//{
//    planetaryHourDataKey = planetaryHourDataKey % 5;
//    [self planetaryHour:hour date:date location:location withCompletion:^(NSDictionary * _Nonnull planetaryHourData) {
//        //        planetaryHourDataObject(planetaryHourData[planetaryHourDataKey]);
//    }];
//}

//void(^currentPlanetaryHourAtLocation)(CLLocation * _Nullable, CurrentPlanetaryHourCompletionBlock) = ^(CLLocation * _Nullable location, CurrentPlanetaryHourCompletionBlock currentPlanetaryHour)
//{
//    location = (CLLocationCoordinate2DIsValid(location.coordinate)) ? locationManager.location : location;
//    cachedSunriseSunsetData(location, [NSDate date],
//                            ^(NSArray<NSDate *> * _Nonnull sunriseSunsetDates, NSArray<NSNumber *> * _Nonnull hourDurations) {
//                                __block NSUInteger hour = 0;
//                                __block dispatch_block_t planetaryHoursDictionaries;
//                                
//                                void(^planetaryHoursDictionary)(NSInteger) = ^(NSInteger index) {
//                                    NSTimeInterval startTimeInterval = hourDurations[index].doubleValue * hour;
//                                    NSDate *startTime                = [[NSDate alloc] initWithTimeInterval:startTimeInterval sinceDate:sunriseSunsetDates[index]];
//                                    NSTimeInterval endTimeInterval   = hourDurations[index].doubleValue * (hour + 1);
//                                    NSDate *endTime                  = [[NSDate alloc] initWithTimeInterval:endTimeInterval sinceDate:sunriseSunsetDates[index]];
//                                    
//                                    NSDateInterval *dateInterval = [[NSDateInterval alloc] initWithStartDate:startTime endDate:endTime];
//                                    if (![dateInterval containsDate:[NSDate date]])
//                                    {
//                                        hour++;
//                                        planetaryHoursDictionaries();
//                                    } else {
//                                        currentPlanetaryHour(planetaryHourData(hourDurations, hour, sunriseSunsetDates, location.coordinate));
//                                    }
//                                };
//                                
//                                planetaryHoursDictionaries = ^{
//                                    planetaryHoursDictionary((hour < HOURS_PER_SOLAR_TRANSIT) ? 0 : 1);
//                                };
//                                planetaryHoursDictionaries();
//                            });
//};
//
//void(^planetaryHourBlock)(NSUInteger, NSDate * _Nullable, CLLocation * _Nullable, PlanetaryHourCompletionBlock) = ^(NSUInteger hour, NSDate * _Nullable date, CLLocation * _Nullable location, PlanetaryHourCompletionBlock planetaryHourCompletionBlock)
//{
//    location = (CLLocationCoordinate2DIsValid(location.coordinate)) ? locationManager.location : location;
//    cachedSunriseSunsetData(location, (!date) ? [NSDate date] : date,
//                            ^(NSArray<NSDate *> * _Nonnull sunriseSunsetDates, NSArray<NSNumber *> * _Nonnull hourDurations) {
//                                planetaryHourCompletionBlock(planetaryHourData(hourDurations, hour, sunriseSunsetDates, location.coordinate));
//                            });
////    return ^NSDictionary *(NSDictionary *currentPlanetaryHourData) {
////        return planetaryHourData(hourDurations, hour, sunriseSunsetDates, location.coordinate));
////    };
//};

//- (NSDictionary *)planetaryDataForHour:(NSUInteger) hour date:(NSArray<NSDate *> *)sunriseSunsetDates location:(CLLocation *)location
//{
//    return planetaryHourData([NSArray new], hour, sunriseSunsetDates, location.coordinate);
//}



#pragma mark - EventKit

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

EKEvent *(^planetaryHourEvent)(NSUInteger, EKEventStore *, EKCalendar *, NSArray<NSNumber *> *, NSArray<NSDate *> *, CLLocation *) = ^(NSUInteger hour, EKEventStore *eventStore, EKCalendar *calendar, NSArray<NSNumber *> *hourDurations, NSArray<NSDate *> *dates, CLLocation *location)
{
    Meridian meridian                = (hour < HOURS_PER_SOLAR_TRANSIT) ? AM : PM;
    SolarTransit transit             = (hour < HOURS_PER_SOLAR_TRANSIT) ? Sunrise : Sunset;
    Planet planet                    = planetForDay(dates.firstObject);
    NSUInteger planetStringIndex     = ((planet + hour) % NUMBER_OF_PLANETS);
    NSString *symbol                 = planetSymbol(planetStringIndex);
    NSString *name                   = planetName(planetStringIndex);
    NSTimeInterval startTimeInterval = hourDurations[meridian].doubleValue * hour;
    NSDate *startTime                = [[NSDate alloc] initWithTimeInterval:startTimeInterval sinceDate:dates[transit]];
    NSTimeInterval endTimeInterval   = hourDurations[meridian].doubleValue * (hour + 1);
    NSDate *endTime                  = [[NSDate alloc] initWithTimeInterval:endTimeInterval sinceDate:dates[transit]];
    
    EKEvent *event     = [EKEvent eventWithEventStore:eventStore];
    event.calendar     = calendar;
    event.title        = [NSString stringWithFormat:@"%@\t%@", symbol, name];
    event.availability = EKEventAvailabilityFree;
    event.alarms       = @[[EKAlarm alarmWithAbsoluteDate:startTime]];
    event.location     = [NSString stringWithFormat:@"%f, %f", location.coordinate.latitude, location.coordinate.longitude];
    event.notes        = [NSString stringWithFormat:@"%@\t%@", symbol, name];
    event.startDate    = startTime;
    event.endDate      = endTime;
    event.allDay       = NO;
    
    return event;
};

void(^calendarPlanetaryHoursForDate)(NSDate * _Nullable, CLLocation * _Nullable, dispatch_block_t) = ^(NSDate * _Nullable date, CLLocation * _Nullable location, dispatch_block_t block) {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    location = (CLLocationCoordinate2DIsValid(location.coordinate)) ? locationManager.location : location;
    date     = (!date) ? [NSDate date] : date;
    cachedSunriseSunsetData(location, date, ^(NSArray<NSDate *> * _Nonnull dates, NSArray<NSNumber *> *hourDurations) {
        [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
            if (granted)
            {
                calendarForEventStore(eventStore, ^(EKCalendar *calendar) {
                    for (long hour = 0; hour < HOURS_PER_SOLAR_TRANSIT; hour++)
                    {
                        __autoreleasing NSError *error;
                        if ([eventStore saveEvent:planetaryHourEvent(hour, eventStore, calendar, hourDurations, dates, location) span:EKSpanThisEvent error:&error])
                        {
                            NSLog(@"Event %lu saved.", (hour + 1));
                        } else {
                            NSLog(@"Error saving event: %@", error.description);
                        }
                    }
                });
            } else {
                NSLog(@"Access to event store denied: %@", error.description);
            }
            block();
        }];
    });
};

void(^planetaryHourEventBlock)(NSUInteger, NSDate * _Nullable, CLLocation * _Nullable, PlanetaryHourEventCompletionBlock) = ^(NSUInteger hour, NSDate * _Nullable date, CLLocation * _Nullable location, PlanetaryHourEventCompletionBlock completionBlock)
{
    NSLog(@"EVENT FOR HOUR:\t%lu\n%s", hour + 1, __PRETTY_FUNCTION__);
    location = (CLLocationCoordinate2DIsValid(location.coordinate)) ? locationManager.location : location;
    date     = (!date) ? [NSDate date] : date;
    hour     = hour % 24;
    cachedSunriseSunsetData(location, date, ^(NSArray<NSDate *> * _Nonnull dates, NSArray<NSNumber *> *hourDurations) {
        [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
            if (granted)
            {
                calendarForEventStore(eventStore, ^(EKCalendar *calendar) {
                    EKEvent *event = planetaryHourEvent(hour, eventStore, calendar, hourDurations, dates, location);
                    __autoreleasing NSError *error;
                    if ([eventStore saveEvent:event span:EKSpanThisEvent error:&error])
                    {
                        NSLog(@"Event %lu saved.", (hour + 1));
                        completionBlock(event);
                    } else {
                        NSLog(@"Error saving event: %@", error.description);
                    }
                });
            } else {
                NSLog(@"Access to event store denied: %@", error.description);
            }
        }];
    });
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


@end
