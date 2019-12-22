// @flow

import { NativeEventEmitter, NativeModules } from 'react-native';

const { RNReverseGeocode } = NativeModules;

type Location = {|
  +latitude: number,
  +longitude: number,
|};

type Address = {|
  name: string,
  address: string,
  location: Location,
|};

type Result = $ReadOnlyArray<Address>;

type Region = {|
  ...Location,
  +latitudeDelta: number,
  +longitudeDelta: number,
|};

type CompleterResult = {

}

type Callback = (err: string, res: Result) => void;
type CompleterCallback = (event: CompleterResult) => void

const rnReverseGeocodeEmitter = new NativeEventEmitter(RNReverseGeocode)

const debounce = (fn, time, ...args) => {
  let timeout;

  return () => {
    const functionCall = () => fn.apply(this, args);

    clearTimeout(timeout);
    timeout = setTimeout(functionCall, time);
  };
};

const searchForLocations = (
  searchText: string,
  region: Region,
  callback: Callback,
  debounceMs: number = 200,
) => {
  debounce(
    RNReverseGeocode.searchForLocations(searchText, region, callback),
    debounceMs,
  );
};

const searchForLocationsWithCompleter = (
  searchText: string,
  region: Region,
) => {
  RNReverseGeocode.searchForLocationsWithCompleter(searchText, region)
};

const registerCompleterListener = (callback: CompleterCallback) => {
  return rnReverseGeocodeEmitter.addListener('MKLocalSearchCompleter', callback)
}

const geocodePosition = (position: Location) => {
  if (!position || (!position.latitude && position.latitude !== 0) || (!position.longitude && position.longitude !== 0)) {
    return Promise.reject(new Error("invalid position: {latitude, longitude} required"));
  }

  return RNReverseGeocode.geocodePosition(position)
}

const SearchForLocations = {
  searchForLocations,
  searchForLocationsWithCompleter,
  registerCompleterListener,
  geocodePosition
};

export default SearchForLocations;
