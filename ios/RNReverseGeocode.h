#import <React/RCTBridgeModule.h>
#import <React/RCTConvert.h>
#import <React/RCTEventEmitter.h>

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@interface RCTConvert (CoreLocation)

+ (CLLocation *)CLLocation:(id)json;

@end

@interface RCTConvert (Mapkit)

+ (MKCoordinateSpan)MKCoordinateSpan:(id)json;
+ (MKCoordinateRegion)MKCoordinateRegion:(id)json;

@end

@interface RNReverseGeocode : RCTEventEmitter <RCTBridgeModule, MKLocalSearchCompleterDelegate>
@property (nonatomic, strong) CLGeocoder *geocoder;

@end
  
