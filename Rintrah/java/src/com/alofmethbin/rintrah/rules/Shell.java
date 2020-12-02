package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.Scanner;
import java.io.File;
import java.io.FileReader;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashSet;

/**
 * Run command to generate HTML page and load into context - if page has already been
 * loaded do not load it a second time
 */
public class Shell extends Rule {
    
    // Constructor
    public Shell(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 2);
    }
    
    /**
     * Cache HTML document from command to file
     * @param urlText URL
     * @return Cache file handle
     * @throws Exception 
     */
    public File cacheCommand( Context context, String command) throws Exception {
        String line;

        // Start shell
        Process process = Runtime.getRuntime().exec("/bin/csh");
        Writer shellScript = new OutputStreamWriter(process.getOutputStream());

        // Issue command
        File cached = context.createTempFile();
        shellScript.write(command + " >" + cached.getPath() + "\n");

        // Wait for shell to finish and check status
        shellScript.close();
        int status = process.waitFor();

        if (status != 0) {
            System.err.println(command);
            throw new Exception("Error running script");
        }

        context.saveCache( command, cached);
        return cached;
    }

    // Execute rule
    @Override
    public void execute(Context context) {
        try {
            Context subContext = context.duplicate();
            String command = evaluate(context, 0).trim();

            // If already seen this command skip it
            if (seen.contains(command)) {
                return;
            }
            seen.add(command);

            // Get days to cache command result
            int days = 10;
            if (this.getArgumentCount() > 1) {
                days = Integer.parseInt( evaluate(context, 1));
            }
            
            // If loaded execute following commands
            if ( load( command, days, subContext) ) {
                String oldUrl = subContext.setMonitor(Scanner.URL, command);
                subContext.execute();
                subContext.setMonitor(Scanner.URL, oldUrl);
            }
        } catch (Throwable t) {
            error(context, t);
        }
    }
    
    /**
     * Load HTML document
     * @param command Command to generate document
     * @param days Days to cache for
     * @return true iff HTML document loaded
     */
    public boolean load(String command, int days, Context context)
            throws Exception {

        // Firstly do we not have this page recently cached?
        File cacheFile = context.getCachedFile(command);
        if (Scanner.older(cacheFile, days) && context.httpLoadNew()) {

            // Try the load
            try {
                cacheFile = cacheCommand( context, command);
                if (cacheFile == null) {return false;}
            } catch (Exception e) {
                context.error(command + ": " + e.getMessage());
            }
        }

        // No file loaded?  Try using cached version
        if (cacheFile == null) {
            cacheFile = context.getCachedFile(command);
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
        
        // Parse the cached file
        context.load( command, new FileReader(cacheFile)); // , pluginName);
        return true;
    }
    
    // Commands already seen 
    private java.util.Set<String> seen = new HashSet<String>();
}
