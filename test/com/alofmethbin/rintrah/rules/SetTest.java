package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class SetTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "SetTest", "test", "Hello World");
    }
}