//
//  PlanetaryHourDataSource.h
//  JBPlanetaryHourCalculator
//
//  Created by Xcode Developer on 10/23/18.
//  Copyright © 2018 Xcode Developer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <EventKit/EventKit.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, Planet) {
    Sun,
    Moon,
    Mars,
    Mercury,
    Jupiter,
    Venus,
    Saturn
};

typedef NS_ENUM(NSUInteger, Day) {
    SUN,
    MON,
    TUE,
    WED,
    THU,
    FRI,
    SAT
};

NSString *(^planetSymbol)(Planet) = ^(Planet planet) {
    switch (planet) {
        case Sun:
            return @"☉";
            break;
        case Moon:
            return @"☽";
            break;
        case Mars:
            return @"♂︎";
            break;
        case Mercury:
            return @"☿";
            break;
        case Jupiter:
            return @"♃";
            break;
        case Venus:
            return @"♀︎";
            break;
        case Saturn:
            return @"♄";
            break;
        default:
            break;
    }
};

NSString *(^planetName)(Planet) = ^(Planet planet) {
    switch (planet) {
        case Sun:
            return @"Sun";
            break;
        case Moon:
            return @"Moon";
            break;
        case Mars:
            return @"Mars";
            break;
        case Mercury:
            return @"Mercury";
            break;
        case Jupiter:
            return @"Jupiter";
            break;
        case Venus:
            return @"Venus";
            break;
        case Saturn:
            return @"Saturn";
            break;
        default:
            break;
    }
};

UIColor *(^planetColor)(Planet) = ^(Planet planet) {
    switch (planet) {
        case Sun:
            return [UIColor yellowColor];
            break;
        case Moon:
            return [UIColor whiteColor];
            break;
        case Mars:
            return [UIColor redColor];
            break;
        case Mercury:
            return [UIColor brownColor];
            break;
        case Jupiter:
            return [UIColor orangeColor];
            break;
        case Venus:
            return [UIColor greenColor];
            break;
        case Saturn:
            return [UIColor grayColor];
            break;
        default:
            break;
    }
};

NSString * const kPlanetaryHourSymbolDataKey   = @"PlanetaryHourSymbolDataKey";
NSString * const kPlanetaryHourNameDataKey     = @"PlanetaryHourNameDataKey";
NSString * const kPlanetaryHourBeginDataKey    = @"PlanetaryHourBeginDataKey";
NSString * const kPlanetaryHourEndDataKey      = @"PlanetaryHourEndDataKey";
NSString * const kPlanetaryHourLocationDataKey = @"PlanetaryHourLocationDataKey";

typedef NS_ENUM(NSUInteger, PlanetaryHourDataKey) {
    PlanetaryHourSymbolDataKey,
    PlanetaryHourNameDataKey,
    PlanetaryHourBeginDataKey,
    PlanetaryHourEndDataKey,
    PlanetaryHourLocationDataKey
};

typedef void(^CachedSunriseSunsetDataWithCompletionBlock)(NSArray<NSDate *> *sunriseSunsetDates);
typedef void(^CachedSunriseSunsetData)(CLLocation * _Nullable, NSDate  * _Nullable , CachedSunriseSunsetDataWithCompletionBlock);

typedef void(^CurrentPlanetaryHourCompletionBlock)(NSDictionary *currentPlanetaryHour);
typedef void(^CurrentPlanetaryHourBlock)(CLLocation * _Nullable location, CurrentPlanetaryHourCompletionBlock currentPlanetaryHour);

typedef void(^CalendarForEventStoreCompletionBlock)(EKCalendar *calendar);
typedef void(^CalendarForEventStore)(EKEventStore *eventStore, CalendarForEventStoreCompletionBlock completionBlock);
typedef void(^CalendarPlanetaryHourEventsCompletionBlock)(void);
typedef void(^CalendarPlanetaryHours)(NSArray <NSDate *> *dates, CLLocation *location, CalendarPlanetaryHourEventsCompletionBlock completionBlock);


#define SECONDS_PER_DAY 86400.00f
#define HOURS_PER_SOLAR_TRANSIT 12
#define HOURS_PER_DAY 24

@interface PlanetaryHourDataSource : NSObject <CLLocationManagerDelegate>

@property (strong, nonatomic) dispatch_queue_t planetaryHourDataRequestQueue;
@property (class, strong, nonatomic, readonly) NSArray<NSString *> *planetaryHourDataKeys;

- (void)planetaryHours:(_Nullable NSRangePointer *)hours date:(nullable NSDate *)date location:(nullable CLLocation *)location withCompletion:(void(^)(NSArray<NSDictionary *> *))planetaryHoursData;
- (void)planetaryHour:(NSUInteger)hour date:(nullable NSDate *)date location:(nullable CLLocation *)location withCompletion:(void(^)(NSDictionary *))planetaryHourData;
- (void)planetaryHour:(NSUInteger)hour date:(nullable NSDate *)date location:(nullable CLLocation *)location objectForKey:(PlanetaryHourDataKey)planetaryHourDataKey withCompletion:(void(^)(NSString *))planetaryHourDataObject;

@property (copy) NSDictionary *(^PlanetaryHour)(Planet planet, NSTimeInterval hourDuration, NSUInteger hour, NSDate *start, CLLocationCoordinate2D coordinate);
@property (copy) void(^cachedSunriseSunsetData)(CLLocation * _Nullable location, NSDate * _Nullable date, CachedSunriseSunsetDataWithCompletionBlock sunriseSunsetData);
@property (copy) void(^currentPlanetaryHour)(CLLocation * _Nullable location, CurrentPlanetaryHourCompletionBlock currentPlanetaryHour);

@property (copy) void(^calendarForEventStore)(EKEventStore *eventStore, CalendarForEventStoreCompletionBlock completionBlock);
@property (copy) void(^calendarPlanetaryHours)(NSArray <NSDate *> *dates, CLLocation *location, CalendarForEventStoreCompletionBlock completionBlock);

+ (nonnull PlanetaryHourDataSource *)sharedDataSource;
+ (NSArray<NSString *> *)planetaryHourDataKeys;

@end

NS_ASSUME_NONNULL_END
