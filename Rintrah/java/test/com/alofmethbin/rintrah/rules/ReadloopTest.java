package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class ReadloopTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        //System.err.println( System.getProperty("user.dir"));
        expectWrite( "ReadloopTest", "test", "Apple", "Date");
    }
}
