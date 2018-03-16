package com.stionic.facebookads;

import java.util.HashMap;
import java.util.Iterator;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;
import org.apache.cordova.PluginResult.Status;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import android.annotation.TargetApi;
import android.app.Activity;
import android.os.Build;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.View.OnTouchListener;
import android.widget.RelativeLayout;
import com.facebook.ads.*;
import com.facebook.ads.NativeAd.Image;
import com.facebook.ads.NativeAd.Rating;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;

public class FacebookAdPlugin extends CordovaPlugin {
	private static final String LOGTAG = "StionicFacebookAds";

	public static final String ACTION_CREATE_NATIVEAD = "createNativeAd";
	public static final String ACTION_REMOVE_NATIVEAD = "removeNativeAd";
	public static final String ACTION_SET_NATIVEAD_CLICKAREA = "setNativeAdClickArea";

	private RelativeLayout layout;

	public class FlexNativeAd {
		public String adId;
		public int x, y, w, h;
		public NativeAd ad;
		public View view;
		public View tracking;
	};

	private HashMap<String, FlexNativeAd> nativeAds = new HashMap<String, FlexNativeAd>();

	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		super.initialize(cordova, webView);
	}

	@Override
	public boolean execute(String action, JSONArray inputs, CallbackContext callbackContext) throws JSONException {
		PluginResult result = null;

		if (ACTION_CREATE_NATIVEAD.equals(action)) {
			String adid = inputs.optString(0);
			this.createNativeAd(adid);
			result = new PluginResult(Status.OK);

		} else if (ACTION_REMOVE_NATIVEAD.equals(action)) {
			String adid = inputs.optString(0);
			this.removeNativeAd(adid);
			result = new PluginResult(Status.OK);

		} else if (ACTION_SET_NATIVEAD_CLICKAREA.equals(action)) {
			String adid = inputs.optString(0);
			int x = inputs.optInt(1);
			int y = inputs.optInt(2);
			int w = inputs.optInt(3);
			int h = inputs.optInt(4);
			this.setNativeAdClickArea(adid, x, y, w, h);
			result = new PluginResult(Status.OK);
		} else {
			return super.execute(action, inputs, callbackContext);
		}

		if (result != null)
			callbackContext.sendPluginResult(result);

		return true;
	}

	public void createNativeAd(final String adId) {
		Log.d(LOGTAG, "createNativeAd: " + adId);
		final Activity activity = cordova.getActivity();
		activity.runOnUiThread(new Runnable() {
			@Override
			public void run() {
				if (nativeAds.containsKey(adId)) {
					removeNativeAd(adId);
				}

				if (layout == null) {
					layout = new RelativeLayout(cordova.getActivity());
					RelativeLayout.LayoutParams params = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT,
							RelativeLayout.LayoutParams.MATCH_PARENT);
					ViewGroup parentView = (ViewGroup) webView.getView().getRootView();
					parentView.addView(layout, params);
				}

				FlexNativeAd unit = new FlexNativeAd();
				unit.adId = adId;
				unit.x = unit.y = 0;
				unit.w = unit.h = 4;

				unit.view = new View(cordova.getActivity());
				unit.tracking = new View(cordova.getActivity());
				layout.addView(unit.tracking, new RelativeLayout.LayoutParams(unit.w, unit.h));
				layout.addView(unit.view, new RelativeLayout.LayoutParams(unit.w, unit.h));

				// pass scroll event in tracking view to webview to improve UX
				final View webV = webView.getView();
				final View trackingV = unit.tracking;
				final View touchV = unit.view;
				OnTouchListener t = new OnTouchListener() {
					public float mTapX = 0, mTapY = 0;

					@Override
					public boolean onTouch(View v, MotionEvent evt) {
						switch (evt.getAction()) {
						case MotionEvent.ACTION_DOWN:
							mTapX = evt.getX();
							mTapY = evt.getY();
							break;

						case MotionEvent.ACTION_UP:
							boolean clicked = (Math.abs(evt.getX() - mTapX) + Math.abs(evt.getY() - mTapY) < 10);
							mTapX = 0;
							mTapY = 0;
							if (clicked) {
								evt.setAction(MotionEvent.ACTION_DOWN);
								trackingV.dispatchTouchEvent(evt);
								evt.setAction(MotionEvent.ACTION_UP);
								return trackingV.dispatchTouchEvent(evt);
							}
							break;
						}

						// adjust touch event location to web view
						int offsetWebV[] = { 0, 0 }, offsetTouchView[] = { 0, 0 };
						touchV.getLocationOnScreen(offsetTouchView);
						webV.getLocationOnScreen(offsetWebV);
						evt.offsetLocation(offsetTouchView[0] - offsetWebV[0], offsetTouchView[1] - offsetWebV[1]);

						return webV.dispatchTouchEvent(evt);
					}
				};
				unit.view.setOnTouchListener(t);

				unit.ad = new NativeAd(cordova.getActivity(), adId);
				unit.ad.setAdListener(new AdListener() {
					@Override
					public void onError(Ad ad, AdError error) {
						JSONObject data = new JSONObject();
						try {
							data.put("code", error.getErrorCode());
							data.put("message", error.getErrorMessage());
						} catch (JSONException e) {
							e.printStackTrace();
						}
						fireAdEvent("stionic.native.failed", data);
					}

					@Override
					public void onAdLoaded(Ad ad) {
						fireNativeAdLoadEvent(ad);
					}

					@Override
					public void onAdClicked(Ad ad) {
						fireAdEvent("stionic.native.clicked");
					}

					@Override
					public void onLoggingImpression(Ad ad) {
						// Ad impression logged callback
					}
				});

				nativeAds.put(adId, unit);
				unit.ad.loadAd();
			}
		});
	}

	public void fireNativeAdLoadEvent(Ad ad) {
		Iterator<String> it = nativeAds.keySet().iterator();
		while (it.hasNext()) {
			String key = it.next();
			FlexNativeAd unit = nativeAds.get(key);
			if ((unit != null) && (unit.ad == ad)) {
				JSONObject json = new JSONObject();
				try {
					String titleForAd = unit.ad.getAdTitle();
					Image coverImage = unit.ad.getAdCoverImage();
					Image iconForAd = unit.ad.getAdIcon();
					String socialContextForAd = unit.ad.getAdSocialContext();
					String titleForAdButton = unit.ad.getAdCallToAction();
					String textForAdBody = unit.ad.getAdBody();

					json.put("adId", unit.adId);

					JSONObject adRes = new JSONObject();
					adRes.put("title", titleForAd);
					adRes.put("socialContext", socialContextForAd);
					adRes.put("buttonText", titleForAdButton);
					adRes.put("body", textForAdBody);

					JSONObject coverInfo = new JSONObject();
					if (coverImage != null) {
						coverInfo.put("url", coverImage.getUrl());
						coverInfo.put("width", coverImage.getWidth());
						coverInfo.put("height", coverImage.getHeight());
					}

					JSONObject iconInfo = new JSONObject();
					if (iconForAd != null) {
						iconInfo.put("url", iconForAd.getUrl());
						iconInfo.put("width", iconForAd.getWidth());
						iconInfo.put("height", iconForAd.getHeight());
					}

					adRes.put("coverImage", coverInfo);
					adRes.put("icon", iconInfo);
					json.put("adRes", adRes);
				} catch (Exception e) {
					Log.e(LOGTAG, "Error:", e);
				}
				if (unit.ad != null) {
					unit.ad.unregisterView();
					unit.ad.registerViewForInteraction(unit.tracking);
				}
				fireAdEvent("stionic.native.loaded", json);
				break;
			}
		}
	}

	public void removeNativeAd(final String adId) {
		final Activity activity = cordova.getActivity();
		activity.runOnUiThread(new Runnable() {
			@Override
			public void run() {
				if (nativeAds.containsKey(adId)) {
					FlexNativeAd unit = nativeAds.remove(adId);
					if (unit.view != null) {
						ViewGroup parentView = (ViewGroup) unit.view.getParent();
						if (parentView != null) {
							parentView.removeView(unit.view);
						}
						unit.view = null;
					}
					if (unit.ad != null) {
						unit.ad.unregisterView();
						unit.ad.destroy();
						unit.ad = null;
					}
				}
			}
		});
	}

	@TargetApi(Build.VERSION_CODES.HONEYCOMB)
	public void setNativeAdClickArea(final String adId, int x, int y, int w, int h) {
		final FlexNativeAd unit = nativeAds.get(adId);
		if (unit != null) {
			DisplayMetrics metrics = cordova.getActivity().getResources().getDisplayMetrics();
			unit.x = (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, x, metrics);
			unit.y = (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, y, metrics);
			unit.w = (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, w, metrics);
			unit.h = (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, h, metrics);

			View rootView = webView.getView().getRootView();
			int offsetRootView[] = { 0, 0 }, offsetMainView[] = { 0, 0 };
			rootView.getLocationOnScreen(offsetRootView);
			webView.getView().getLocationOnScreen(offsetMainView);
			unit.x += (offsetMainView[0] - offsetRootView[0]);
			unit.y += (offsetMainView[1] - offsetRootView[1]);

			final Activity activity = cordova.getActivity();
			activity.runOnUiThread(new Runnable() {
				@Override
				public void run() {
					if (unit.view != null) {
						unit.view.setLeft(unit.x);
						unit.view.setTop(unit.y);
						unit.view.setRight(unit.x + unit.w);
						unit.view.setBottom(unit.y + unit.h);
					}
					if (unit.tracking != null) {
						unit.tracking.setLeft(unit.x);
						unit.tracking.setTop(unit.y);
						unit.tracking.setRight(unit.x + unit.w);
						unit.tracking.setBottom(unit.y + unit.h);
					}
				}
			});
		}
	}

	public void fireAdEvent(String eventName) {
		String js = new CordovaEventBuilder(eventName).build();
		loadJS(js);
	}

	public void fireAdEvent(String eventName, JSONObject data) {
		String js = new CordovaEventBuilder(eventName).withData(data).build();
		loadJS(js);
	}

	private void loadJS(String js) {
		webView.loadUrl(js);
	}
}