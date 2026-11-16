package kr.co.nepkorea.mobile;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.ClipData;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsets.Type;
import android.webkit.*;
import android.widget.*;
import java.io.*;
import java.util.Locale;

public final class MainActivity extends Activity {
    private static final String HOST = "nepkoreateam.github.io";
    private static final String PREFIX = "/nep-korea-system/";
    private static final String URL = "https://" + HOST + PREFIX;
    private static final int FILE_PICK = 71, GEO_PERMISSION = 72, EXPORT_FILE = 73;
    private WebView web;
    private LinearLayout root, offline;
    private ProgressBar progress;
    private ValueCallback<Uri[]> fileResult;
    private GeolocationPermissions.Callback geoCallback;
    private String geoOrigin;
    private String exportFilename;
    private byte[] exportBytes;
    private boolean loadingError = false;
    private final Handler main = new Handler(Looper.getMainLooper());

    private boolean isOrigin(Uri u) {
        return u != null && "https".equalsIgnoreCase(u.getScheme())
            && HOST.equalsIgnoreCase(u.getHost()) && (u.getPort() == -1 || u.getPort() == 443)
            && u.getUserInfo() == null;
    }
    private boolean isApp(Uri u) {
        if (!isOrigin(u)) return false;
        String p = u.getPath();
        return p != null && (p.equals("/nep-korea-system") || p.startsWith(PREFIX))
            && !p.contains("/../");
    }
    private boolean trustedPage() { return web != null && isApp(Uri.parse(web.getUrl() == null ? "" : web.getUrl())); }
    private int dp(int n) { return Math.round(n * getResources().getDisplayMetrics().density); }

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().setStatusBarColor(Color.rgb(15,63,140));
        getWindow().setNavigationBarColor(Color.WHITE);
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.rgb(245,247,251));
        if (Build.VERSION.SDK_INT >= 30) {
            getWindow().setDecorFitsSystemWindows(false);
            root.setOnApplyWindowInsetsListener((view,insets) -> {
                android.graphics.Insets sys = insets.getInsets(Type.systemBars() | Type.displayCutout());
                android.graphics.Insets ime = insets.getInsets(Type.ime());
                view.setPadding(sys.left,sys.top,sys.right,Math.max(sys.bottom,ime.bottom));
                return insets;
            });
        }
        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL); header.setPadding(dp(16),dp(3),dp(6),dp(3));
        header.setBackgroundColor(Color.rgb(15,63,140));
        TextView title = new TextView(this);
        title.setText("NEP KOREA"); title.setTextColor(Color.WHITE); title.setTextSize(17);
        title.setTypeface(null,android.graphics.Typeface.BOLD);
        header.addView(title,new LinearLayout.LayoutParams(0,dp(40),1));
        title.setGravity(Gravity.CENTER_VERTICAL);
        TextView reload = new TextView(this);
        reload.setText("↻"); reload.setContentDescription("새로고침"); reload.setTextColor(Color.WHITE);
        reload.setTextSize(27); reload.setGravity(Gravity.CENTER); reload.setPadding(dp(10),0,dp(10),0);
        reload.setOnClickListener(v -> loadHome(false));
        header.addView(reload,new LinearLayout.LayoutParams(dp(48),dp(44)));
        root.addView(header);
        progress = new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);
        root.addView(progress,new LinearLayout.LayoutParams(-1,dp(3)));
        FrameLayout frame = new FrameLayout(this);
        root.addView(frame,new LinearLayout.LayoutParams(-1,0,1));
        web = new WebView(this);
        frame.addView(web,new FrameLayout.LayoutParams(-1,-1));
        offline = new LinearLayout(this);
        offline.setOrientation(LinearLayout.VERTICAL); offline.setGravity(Gravity.CENTER);
        offline.setPadding(dp(28),dp(28),dp(28),dp(28)); offline.setBackgroundColor(Color.rgb(245,247,251));
        TextView heading = new TextView(this); heading.setText("연결을 확인해주세요");
        heading.setTextSize(22); heading.setTextColor(Color.rgb(15,63,140));
        heading.setTypeface(null,android.graphics.Typeface.BOLD); offline.addView(heading);
        TextView msg = new TextView(this);
        msg.setText("인터넷 연결을 확인한 후 다시 시도해주세요.\n저장 완료를 확인하기 전에는 수거 완료로 처리되지 않습니다.");
        msg.setGravity(Gravity.CENTER); msg.setTextSize(15); msg.setTextColor(Color.DKGRAY);
        LinearLayout.LayoutParams mp = new LinearLayout.LayoutParams(-1,-2); mp.setMargins(0,dp(12),0,dp(18));
        offline.addView(msg,mp);
        Button retry = new Button(this); retry.setText("다시 연결"); retry.setOnClickListener(v->loadHome(true)); offline.addView(retry);
        offline.setVisibility(View.GONE); frame.addView(offline,new FrameLayout.LayoutParams(-1,-1));
        setContentView(root);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true); s.setDomStorageEnabled(true); s.setGeolocationEnabled(true);
        s.setAllowFileAccess(false); s.setAllowContentAccess(true);
        s.setAllowFileAccessFromFileURLs(false); s.setAllowUniversalAccessFromFileURLs(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setJavaScriptCanOpenWindowsAutomatically(false); s.setSupportMultipleWindows(false);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        if (Build.VERSION.SDK_INT >= 26) s.setSafeBrowsingEnabled(true);
        CookieManager.getInstance().setAcceptCookie(true);
        CookieManager.getInstance().setAcceptThirdPartyCookies(web,false);
        WebView.setWebContentsDebuggingEnabled(false);
        web.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                if (!r.isForMainFrame()) return false;
                Uri u = r.getUrl();
                if (isApp(u)) return false;
                openExternal(u); return true;
            }
            @Override public boolean shouldOverrideUrlLoading(WebView v,String url) {
                Uri u=Uri.parse(url); if(isApp(u))return false; openExternal(u);return true;
            }
            @Override public void onPageStarted(WebView v,String url,android.graphics.Bitmap icon) {
                super.onPageStarted(v,url,icon);
                if (isApp(Uri.parse(url))) { loadingError=false; offline.setVisibility(View.GONE); }
                progress.setVisibility(View.VISIBLE);
            }
            @Override public void onPageFinished(WebView v,String url) {
                if (isApp(Uri.parse(url)) && !loadingError) offline.setVisibility(View.GONE);
                progress.setVisibility(View.GONE);
                CookieManager.getInstance().flush();
            }
            @Override public void onReceivedError(WebView v,WebResourceRequest req,WebResourceError err) {
                if(req.isForMainFrame()) showOffline();
            }
            @Override public void onReceivedHttpError(WebView v,WebResourceRequest req,WebResourceResponse response) {
                if(req.isForMainFrame() && response.getStatusCode()>=400) showOffline();
            }
            @Override public void onReceivedSslError(WebView v,SslErrorHandler handler,android.net.http.SslError error) {
                handler.cancel(); showOffline();
            }
        });
        web.setWebChromeClient(new WebChromeClient(){
            @Override public void onProgressChanged(WebView v,int p){progress.setProgress(p);progress.setVisibility(p>=100?View.GONE:View.VISIBLE);}
            @Override public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams params){
                if(!trustedPage()){cb.onReceiveValue(null);return true;}
                if(fileResult!=null) fileResult.onReceiveValue(null);
                fileResult=cb;
                try { startActivityForResult(params.createIntent(), FILE_PICK); }
                catch(Exception e){fileResult=null;cb.onReceiveValue(null);toast("파일을 열 수 없습니다.");}
                return true;
            }
            @Override public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback cb){
                if(!isOrigin(Uri.parse(origin))||!trustedPage()){cb.invoke(origin,false,false);return;}
                if(hasLocation()){cb.invoke(origin,true,false);return;}
                if(geoCallback!=null)geoCallback.invoke(geoOrigin,false,false);
                geoCallback=cb;geoOrigin=origin;
                requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION},GEO_PERMISSION);
            }
            @Override public void onGeolocationPermissionsHidePrompt(){
                if(geoCallback!=null){geoCallback.invoke(geoOrigin,false,false);geoCallback=null;geoOrigin=null;}
            }
            @Override public void onPermissionRequest(PermissionRequest request){request.deny();}
        });
        web.setDownloadListener((url,ua,disposition,mime,len)->handleDownload(url,disposition,mime));
        loadHome(true);
    }
    private void loadHome(boolean home){
        loadingError=false;offline.setVisibility(View.GONE);progress.setVisibility(View.VISIBLE);
        if(home||!trustedPage()) web.loadUrl(URL); else web.reload();
    }
    private void showOffline(){loadingError=true;offline.setVisibility(View.VISIBLE);progress.setVisibility(View.GONE);}
    private boolean hasLocation(){return checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)==PackageManager.PERMISSION_GRANTED
        ||checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED;}
    private void toast(String msg){Toast.makeText(this,msg,Toast.LENGTH_LONG).show();}
    private void openExternal(Uri u){
        String scheme=u.getScheme();
        if(!"https".equalsIgnoreCase(scheme)&&!"tel".equalsIgnoreCase(scheme)&&!"mailto".equalsIgnoreCase(scheme))return;
        try{startActivity(new Intent(Intent.ACTION_VIEW,u));}catch(Exception e){toast("이 링크를 열 수 없습니다.");}
    }
    @Override public void onRequestPermissionsResult(int req,String[] p,int[] result){
        super.onRequestPermissionsResult(req,p,result);
        if(req==GEO_PERMISSION && geoCallback!=null){
            boolean allow=hasLocation()&&trustedPage()&&isOrigin(Uri.parse(geoOrigin));
            geoCallback.invoke(geoOrigin,allow,false);geoCallback=null;geoOrigin=null;
        }
    }
    private String safeName(String name){
        if(name==null||name.trim().isEmpty())name="NEP-export";
        name=name.replaceAll("[\\\\/:*?\"<>|\\p{Cntrl}]","_");
        return name.length()>120?name.substring(0,120):name;
    }
    private void handleDownload(String url,String disposition,String mime){
        if(!trustedPage())return;
        Uri u=Uri.parse(url);
        if(!"blob".equals(u.getScheme())){
            if("https".equals(u.getScheme()))openExternal(u);else toast("지원되지 않는 다운로드입니다.");
            return;
        }
        if(!url.startsWith("blob:https://"+HOST+"/")){toast("신뢰할 수 없는 파일입니다.");return;}
        if(exportBytes!=null){toast("기존 파일 저장을 마쳐주세요.");return;}
        String name=safeName(URLUtil.guessFileName(url,disposition,mime));
        // evaluateJavascript has no permanent native bridge; only the trusted app origin is read.
        String expr="(async function(){try{const r=await fetch("+org.json.JSONObject.quote(url)+");const b=await r.blob();if(b.size>3000000)return 'TOO_LARGE';return await new Promise((resolve,reject)=>{const f=new FileReader();f.onload=()=>resolve(f.result.split(',')[1]);f.onerror=reject;f.readAsDataURL(b);});}catch(e){return 'ERROR';}})()";
        // Async promises are not resolved by evaluateJavascript on Android, so store result in page and poll.
        web.evaluateJavascript("window.__nepNativeDownloadResult=null;"+expr+".then(x=>window.__nepNativeDownloadResult=x);",null);
        pollExport(name,mime,0);
    }
    private void pollExport(String name,String mime,int attempts){
        if(!trustedPage()||attempts>=40){toast("파일 저장에 실패했습니다. PC에서 내려받아주세요.");return;}
        main.postDelayed(()->web.evaluateJavascript("window.__nepNativeDownloadResult",result->{
            if(!trustedPage())return;
            if(result==null||"null".equals(result)){pollExport(name,mime,attempts+1);return;}
            try{
                String s=(String)new org.json.JSONTokener(result).nextValue();
                web.evaluateJavascript("delete window.__nepNativeDownloadResult",null);
                if("ERROR".equals(s)||"TOO_LARGE".equals(s)){toast("파일이 너무 크거나 읽을 수 없습니다. PC에서 내려받아주세요.");return;}
                byte[] bytes=android.util.Base64.decode(s,android.util.Base64.DEFAULT);
                if(bytes.length>3000000)throw new IOException("file too large");
                exportBytes=bytes;exportFilename=name;
                Intent i=new Intent(Intent.ACTION_CREATE_DOCUMENT);i.addCategory(Intent.CATEGORY_OPENABLE);
                i.setType(mime!=null&&mime.contains("/")?mime:"application/octet-stream");i.putExtra(Intent.EXTRA_TITLE,name);
                startActivityForResult(i,EXPORT_FILE);
            }catch(Exception e){exportBytes=null;exportFilename=null;toast("파일을 저장할 수 없습니다.");}
        }),250);
    }
    @Override protected void onActivityResult(int req,int result,Intent data){
        super.onActivityResult(req,result,data);
        if(req==FILE_PICK && fileResult!=null){
            Uri[] values=result==RESULT_OK?WebChromeClient.FileChooserParams.parseResult(result,data):null;
            if(values!=null)for(Uri value:values)if(value==null||!"content".equals(value.getScheme())){values=null;break;}
            ValueCallback<Uri[]> cb=fileResult;fileResult=null;cb.onReceiveValue(trustedPage()?values:null);
        }else if(req==EXPORT_FILE){
            byte[] bytes=exportBytes;exportBytes=null;exportFilename=null;
            if(result==RESULT_OK&&data!=null&&data.getData()!=null&&bytes!=null){
                try(OutputStream out=getContentResolver().openOutputStream(data.getData(),"w")){
                    if(out==null)throw new IOException("no output stream");out.write(bytes);toast("파일을 저장했습니다.");
                }catch(Exception e){toast("파일 저장에 실패했습니다.");}
            }
        }
    }
    @Override public void onBackPressed(){
        if(offline.getVisibility()==View.VISIBLE){loadHome(true);return;}
        if(web.canGoBack()){web.goBack();return;}
        new AlertDialog.Builder(this).setMessage("NEP KOREA 앱을 닫을까요?")
            .setNegativeButton("계속 사용",null).setPositiveButton("닫기",(d,w)->finish()).show();
    }
    @Override protected void onPause(){super.onPause();web.onPause();CookieManager.getInstance().flush();}
    @Override protected void onResume(){super.onResume();if(web!=null)web.onResume();}
    @Override protected void onDestroy(){
        main.removeCallbacksAndMessages(null);
        if(fileResult!=null)fileResult.onReceiveValue(null);
        if(geoCallback!=null)geoCallback.invoke(geoOrigin,false,false);
        if(web!=null){web.stopLoading();web.destroy();}
        super.onDestroy();
    }
}
