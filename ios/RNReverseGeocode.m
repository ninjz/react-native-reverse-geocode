#import <MapKit/MapKit.h>
#import "RNReverseGeocode.h"
#import <React/RCTConvert.h>
#import <CoreLocation/CoreLocation.h>
#import <React/RCTConvert+CoreLocation.h>
#import <React/RCTUtils.h>

@implementation RCTConvert(CoreLocation)

+ (CLLocation *)CLLocation:(id)json
{
  json = [self NSDictionary:json];

  double lat = [RCTConvert double:json[@"latitude"]];
  double lng = [RCTConvert double:json[@"longitude"]];
  return [[CLLocation alloc] initWithLatitude:lat longitude:lng];
}

@end

@implementation RCTConvert(MapKit)

+ (MKCoordinateSpan)MKCoordinateSpan:(id)json
{
    json = [self NSDictionary:json];
    return (MKCoordinateSpan){
        [self CLLocationDegrees:json[@"latitudeDelta"]],
        [self CLLocationDegrees:json[@"longitudeDelta"]]
    };
}

+ (MKCoordinateRegion)MKCoordinateRegion:(id)json
{
    return (MKCoordinateRegion){
        [self CLLocationCoordinate2D:json],
        [self MKCoordinateSpan:json]
    };
}

@end

@implementation RNReverseGeocode
{
    MKLocalSearch *localSearch;
    MKLocalSearchCompleter *completer;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"MKLocalSearchCompleter"];
}

- (NSArray *)formatLocalSearchCallback:(MKLocalSearchResponse *)localSearchResponse
{
    NSMutableArray *RCTResponse = [[NSMutableArray alloc] init];
    
    for (MKMapItem *mapItem in localSearchResponse.mapItems) {
        NSMutableDictionary *formedLocation = [[NSMutableDictionary alloc] init];
        
        [formedLocation setValue:mapItem.name forKey:@"name"];
        [formedLocation setValue:mapItem.placemark.title forKey:@"address"];
        [formedLocation setValue:@{@"latitude": @(mapItem.placemark.coordinate.latitude),
                                   @"longitude": @(mapItem.placemark.coordinate.longitude)} forKey:@"location"];
        
        [RCTResponse addObject:formedLocation];
    }
    
    return [RCTResponse copy];
}

- (NSArray *)formatLocalSearchCompletionResults:(NSArray<MKLocalSearchCompletion *> *)results
{
    NSMutableArray *RCTResponse = [[NSMutableArray alloc] init];
    
    for (MKLocalSearchCompletion *completion in results) {
        NSMutableDictionary *location = [[NSMutableDictionary alloc] init];
        
        [location setValue:completion.title forKey:@"title"];
        [location setValue:completion.subtitle forKey:@"subtitle"];
        
        [RCTResponse addObject:location];
    }
    
    return [RCTResponse copy]; 
}

- (void) completerDidUpdateResults:(MKLocalSearchCompleter *)completer {
    [self sendEventWithName:@"MKLocalSearchCompleter" body:@{
        @"results": [self formatLocalSearchCompletionResults:completer.results]
    }];
}
 
- (void) completer:(MKLocalSearchCompleter *)completer didFailWithError:(NSError *)error {
    NSLog(@"Completer failed with error: %@",error.description);
}

RCT_EXPORT_METHOD(searchForLocationsWithCompleter:(NSString *)searchText near:(MKCoordinateRegion)region)
{
    if (!completer) {
        completer = [[MKLocalSearchCompleter alloc] init];
        completer.delegate = self;
        completer.filterType = MKSearchCompletionFilterTypeLocationsOnly;
    }
    
    completer.queryFragment = searchText;
    completer.region = region;
}

RCT_EXPORT_METHOD(searchForLocations:(NSString *)searchText near:(MKCoordinateRegion)region callback:(RCTResponseSenderBlock)callback)
{
    [localSearch cancel];
    
    MKLocalSearchRequest *searchRequest = [[MKLocalSearchRequest alloc] init];
    searchRequest.naturalLanguageQuery = searchText;
    searchRequest.region = region;

    localSearch = [[MKLocalSearch alloc] initWithRequest:searchRequest];
    
    __weak RNReverseGeocode *weakSelf = self;
    [localSearch startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        
        if (error) {
            callback(@[RCTMakeError(@"Failed to make local search. ", error, @{@"key": searchText}), [NSNull null]]);
        } else {
            NSArray *RCTResponse = [weakSelf formatLocalSearchCallback:response];
            callback(@[[NSNull null], RCTResponse]);
        }
    }];
}

RCT_EXPORT_METHOD(geocodePosition:(CLLocation *)location
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (!self.geocoder) {
    self.geocoder = [[CLGeocoder alloc] init];
  }

  if (self.geocoder.geocoding) {
    [self.geocoder cancelGeocode];
  }

  [self.geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {

    if (error) {
      if (placemarks.count == 0) {
          return reject(@"NOT_FOUND", @"geocodePosition failed", error);
      }

      return reject(@"ERROR", @"geocodePosition failed", error);
    }

    resolve([self placemarksToDictionary:placemarks]);

  }];
}

- (NSArray *)placemarksToDictionary:(NSArray *)placemarks {

  NSMutableArray *results = [[NSMutableArray alloc] init];

  for (int i = 0; i < placemarks.count; i++) {
    CLPlacemark* placemark = [placemarks objectAtIndex:i];

    NSString* name = [NSNull null];

    if (![placemark.name isEqualToString:placemark.locality] &&
        ![placemark.name isEqualToString:placemark.thoroughfare] &&
        ![placemark.name isEqualToString:placemark.subThoroughfare])
    {

        name = placemark.name;
    }

    NSArray *lines = placemark.addressDictionary[@"FormattedAddressLines"];

    NSDictionary *result = @{
     @"feature": name,
     @"position": @{
         @"lat": [NSNumber numberWithDouble:placemark.location.coordinate.latitude],
         @"lng": [NSNumber numberWithDouble:placemark.location.coordinate.longitude],
         },
     @"country": placemark.country ?: [NSNull null],
     @"countryCode": placemark.ISOcountryCode ?: [NSNull null],
     @"locality": placemark.locality ?: [NSNull null],
     @"subLocality": placemark.subLocality ?: [NSNull null],
     @"streetName": placemark.thoroughfare ?: [NSNull null],
     @"streetNumber": placemark.subThoroughfare ?: [NSNull null],
     @"postalCode": placemark.postalCode ?: [NSNull null],
     @"adminArea": placemark.administrativeArea ?: [NSNull null],
     @"subAdminArea": placemark.subAdministrativeArea ?: [NSNull null],
     @"formattedAddress": [lines componentsJoinedByString:@", "] ?: [NSNull null]
   };

    [results addObject:result];
  }

  return results;

}

@end
