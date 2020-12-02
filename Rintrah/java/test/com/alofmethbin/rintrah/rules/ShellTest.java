package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class ShellTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "ShellTest", "test", "Hello World");
    }
}