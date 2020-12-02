package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.PrunableContext;
import com.alofmethbin.rintrah.WriteListener;
import java.util.HashSet;

/**
 * Set key iteratively to values in numeric range
 */
public class Range extends Rule
{
    // Constructor

    public Range( String[] args) throws Exception {
        super(args);
        checkMinMaxArgs( 4, 4);
    }

    // Execute rule
    @Override
    public void execute( Context context) {
        try {
            Context sub = context.duplicate();
            final String key = getLiteral( 0);
            int start = evaluateInt( context, 1);
            int incr = evaluateInt( context, 2);
            final int limit = evaluateInt( context, 3);

            sub = new PrunableContext(sub) {
                public void prune() {
                    put( key, limit);
                }
            };
            sub.put( key, start);

            sub.addWriteListener(new WriteListener() {
                public void write(String source, String[] args) throws Exception {
                    lines.add( join( args));
                }
            });

            int nLines = -1;
            while ((nLines < lines.size()) && (sub.getInt( key) <= limit)) {
                nLines = lines.size();
                sub.execute();
                sub.put( key, sub.getInt(key) + incr);
            }
        } catch (Throwable t) {
            error(context, t);
        }
    }

    private String join( String [] args) {
        StringBuilder b = new StringBuilder();
        for (String s: args) {
            b.append( "\t");
            b.append( s);
        }
        return b.toString();
    }

    private HashSet<String> lines = new HashSet<String>();
}
