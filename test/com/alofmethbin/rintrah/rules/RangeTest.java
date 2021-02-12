package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class RangeTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "RangeTest", "once", "10");
        expectWrite( "RangeTest", "twice", "10", "25");
        expectWrite( "RangeTest", "nowrite_stop", "Apple");
    }
}
