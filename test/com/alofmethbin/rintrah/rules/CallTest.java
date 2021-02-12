package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class CallTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "CallTest", "test", "Tallinn");
    }
}
