
var argscheck = require('cordova/argscheck'),
    exec = require('cordova/exec');

var fbanExport = {};

fbanExport.createNativeAd = function(adId, successCallback, failureCallback) {
	cordova.exec( successCallback, failureCallback, 'FacebookAds', 'createNativeAd', [adId] );
};

fbanExport.removeNativeAd = function(adId, successCallback, failureCallback) {
	cordova.exec( successCallback, failureCallback, 'FacebookAds', 'removeNativeAd', [adId] );
};

fbanExport.setNativeAdClickArea = function(adId, x, y, w, h, successCallback, failureCallback) {
	cordova.exec( successCallback, failureCallback, 'FacebookAds', 'setNativeAdClickArea', [adId,x,y,w,h] );
};

module.exports = fbanExport;

