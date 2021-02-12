package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import java.io.BufferedReader;
import java.io.FileReader;

/**
 * Set key(s) iteratively to values in file
 */
public class Readloop extends Rule {
    // Constructor

    public Readloop(String[] args) throws Exception {
        super(args);
        checkMinMaxArgs(2, 9);
    }

    // Execute rule
    @Override
    public void execute(Context context) {
        try {
            Context sub = context.duplicate();
            BufferedReader br = new BufferedReader(new FileReader(evaluate(context, 0)));
            String line;
            while ((line = br.readLine()) != null) {
                String[] parts = line.split("\t");
//                if (parts.length >= getArgumentCount()) {
//                    error(context, "Too many values on line", true);
//                    return;
//                }
                for (int i = 1; i < getArgumentCount(); i++) {
                    if (i <= parts.length) {
                       sub.put(getLiteral(i), parts[i-1]);
                    } else {
                       sub.put(getLiteral(i), "");
                    }
                }
                sub.execute();
            }
            
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
