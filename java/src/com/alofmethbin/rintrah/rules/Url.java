package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.Scanner;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.net.SocketException;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashSet;

/**
 * Fetch HTML page by HTTP request and load into context - if page has already been
 * loaded do not load it a second time
 */
public class Url extends Rule {
    
    // Constructor
    public Url(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 2);
    }
    
    /**
     * Cache HTML document at URL to file
     * @param context
     * @param urlText URL
     * @return Cache file handle
     * @throws Exception 
     */
    public File cacheURL( Context context, String urlText) throws Exception {
        // String line;

        // Run "curl" to fetch page
        ProcessBuilder pb = new ProcessBuilder( "curl", urlText);
        File cached = context.createTempFile();
        pb.redirectOutput( cached);
        pb.start().waitFor();
        return cached;
        
        // Get URL object
//        URL url = new URL(urlText);
//        String site = getSite(urlText);

        // Site already has timed out?
//        if (timeoutSites.contains(site)) {
//            return null;
//        }

        // Fudge around No subject alternative DNS name errors
//        javax.net.ssl.HttpsURLConnection.setDefaultHostnameVerifier(
//            new javax.net.ssl.HostnameVerifier(){
//
//                public boolean verify(String hostname,
//                        javax.net.ssl.SSLSession sslSession) {
//                    if (hostname.equals("localhost")) {
//                        return true;
//                    }
//                    return false;
//                }
//            });

        // Start talking to the server
//        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
//        connection.setRequestProperty("accept", "application/xml,application/xhtml+xml,text/html");
//        connection.setRequestProperty("user-agent", "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_8; en-gb) AppleWebKit/531.9 (KHTML, like Gecko) Version/4.0.3 Safari/531.9");
//        connection.setRequestProperty("accept-language", "en-gb");
//        int code = connection.getResponseCode();
//
//        // Cache the HTML on success
//        if (code == HttpURLConnection.HTTP_OK) {
//            File cached = context.createTempFile();
//            BufferedReader buffer = new BufferedReader(new InputStreamReader(connection.getInputStream()));
//            BufferedWriter writer = new BufferedWriter(new FileWriter(cached));
//
//            while ((line = buffer.readLine()) != null) {
//                writer.write(line);
//                writer.newLine();
//            }
//
//            buffer.close();
//            writer.close();
//
//            // Save entry into cache index file
//            context.saveCache( urlText, cached);
//            return cached;
//        } // Timeout?
//        else if (code == HttpURLConnection.HTTP_CLIENT_TIMEOUT) {
//            timeoutSites.add(site);
//            context.error("Timeout loading " + urlText);
//            return null;
//        } // URL not found?
//        else if (code == HttpURLConnection.HTTP_NOT_FOUND) {
//            context.error("Not found: " + urlText);
//            return null;
//        } // HTTP error
//        else {
//            throw new Exception("HTTP response code=" + code + " accessing " + urlText);
//        }
    }

    // Execute rule
    @Override
    public void execute(Context context) {
        try {
            Context subContext = context.duplicate();
            String url = evaluate(context, 0).trim();

            // Replace any "&amp;"s by & in the URL
            url = url.replace( "&amp;", "&");

            // If already seen this URL skip it
            if (seen.contains(url)) {
                return;
            }
            seen.add(url);

            // Get days to cache document
            int days = 7;
            if (this.getArgumentCount() > 1) {
                days = Integer.parseInt( evaluate(context, 1));
            }
            
            // If loaded execute following commands
            if ( load( url, days, subContext) ) {
                String oldUrl = subContext.setMonitor(Scanner.URL, url);
                subContext.execute();
                subContext.setMonitor(Scanner.URL, oldUrl);
            }
        } catch (Throwable t) {
            error(context, t);
        }
    }
    
    // Get site out of URL
    private static String getSite(String url) {
        if (url.startsWith("http://")) {
            url = url.substring(7);
        }
        int pos = url.indexOf('/');
        if (pos >= 0) {
            return url.substring(0, pos);
        }
        return url;
    }

    /**
     * Load HTML document
     * @param urlText URL to load document from
     * @param days Days to cache for
     * @param context
     * @return true iff HTML document loaded
     * @throws java.lang.Exception
     */
    public boolean load(String urlText, int days, Context context)
            throws Exception {

        // Firstly do we not have this page recently cached?
        File cacheFile = context.getCachedFile(urlText);
        if (Scanner.older(cacheFile, days) && context.httpLoadNew()) {

            // Sleep to avoid server flooding
            try {
                Thread.sleep(3000);
            } catch (InterruptedException ie) {
            }

            // Try the load
            try {
                cacheFile = cacheURL( context, urlText);
                if (cacheFile == null) {return false;}
            } catch (SocketException se) {
                context.error(urlText + ": " + se.getMessage());
            } catch (IOException ioe) {
                context.error(urlText + ": " + ioe.getMessage());
            }
        }

        // No file loaded?  Try using cached version
        if (cacheFile == null) {
            cacheFile = context.getCachedFile(urlText);
            if (cacheFile == null) {
                return false;
            }
            // cacheFile.setLastModified(System.currentTimeMillis());
        }

        // Record file being loaded
        context.put( "CACHE_FILENAME", cacheFile.getName());
        DateFormat dt = new SimpleDateFormat();
        context.put( "CACHE_TIMESTAMP", dt.format( new Date( cacheFile.lastModified())));
        context.recordCacheFile( cacheFile);
        context.saveCache( urlText, cacheFile);
        
        // Parse the cached file
        context.load( urlText, new FileReader(cacheFile)); // , pluginName);
        return true;
    }
    
    // Urls already seen 
    private java.util.Set<String> seen = new HashSet<>();

    // Set of sites with timeouts
    private static java.util.Set<String> timeoutSites = new HashSet<String>();
}
