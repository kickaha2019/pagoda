package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.PrunableContext;
import com.alofmethbin.rintrah.WrapperContext;
import com.alofmethbin.rintrah.WriteListener;
import java.io.File;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashSet;

/**
 * Limit how many new HTTP requests to make
 */
public class LimitNew extends Rule
{
    private class LimitNewContext extends WrapperContext {
        public LimitNewContext(Context delegate, int limit) {
            super( delegate);
            this.limit = limit;
        }

        @Override
        public boolean httpLoadNew() {
            if (! super.httpLoadNew()) {return false;}
            return( limit > 0);
        }
    
        @Override
        public void recordCacheFile(File cacheFile) {
            super.recordCacheFile(cacheFile);
            if ((cacheFile.lastModified() + 1000 * 60 * 60 * 24) >= (new java.util.Date()).getTime()) {
                limit --;
            }
        }
        
        private int limit;
    }
    
    // Constructor
    public LimitNew( String[] args) throws Exception {
        super(args);
        checkMinMaxArgs( 1, 1);
    }

    // Execute rule
    @Override
    public void execute( Context context) {
        try {
            Context sub = context.duplicate();
            int limit = evaluateInt( context, 0);
            sub = new LimitNewContext(sub, limit);
            sub.execute();
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
