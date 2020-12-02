package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class PreviousTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "PreviousTest", "test", "Valerie Davis");
    }
}
