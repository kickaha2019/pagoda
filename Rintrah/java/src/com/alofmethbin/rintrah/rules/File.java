package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.Scanner;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.TreeSet;

/**
 * If filename specified load HTML from it into context.
 *
 * If directory specified loop over all .html files in the directory and load
 * them into context iteratively.
 */
public class File extends Rule {

    // Constructor
    public File(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 1);
    }

    // Execute rule
    @Override
    public void execute(Context context) {
        try {
            Context subContext = context.duplicate();
            String path = evaluate(context, 0).trim();

            // If path is a filesystem directory loop over .html files in
            // that directory
            java.io.File file = new java.io.File(path);
            if (subContext.isDirectory( path)) {

                // Ensure we take HTML files in alphabetical order
                java.util.Set<String> htmlPaths = new TreeSet<String>();
                for (java.io.File f : file.listFiles()) {
                    if (f.getName().endsWith(".html")) {
                        htmlPaths.add(f.getAbsolutePath());
                    }
                }

                for (String p : htmlPaths) {
                    String oldUrl = subContext.setMonitor(Scanner.URL, p);
                    subContext.load( p, subContext.fileReader( p));
                    subContext.execute();
                    subContext.setMonitor(Scanner.URL, oldUrl);
                }
            } else {
                String oldUrl = subContext.setMonitor(Scanner.URL, path);
                subContext.load( path, subContext.fileReader(path));
                DateFormat dt = new SimpleDateFormat();
                subContext.put( "CACHE_TIMESTAMP", dt.format( new Date( file.lastModified())));
                subContext.execute();
                subContext.setMonitor(Scanner.URL, oldUrl);
            }
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
