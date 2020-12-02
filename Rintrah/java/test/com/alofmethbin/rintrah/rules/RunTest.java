package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class RunTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "RunTest", "test", "Desmond");
    }
}