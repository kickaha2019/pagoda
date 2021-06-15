package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class PruneTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "PruneTest", "every", "Valerie Davis");
        expectWrite( "PruneTest", "yreve", "RevealTrans (Duration=2, Transition=23)");
        expectWrite( "PruneTest", "acg", "http://www.adventureclassicgaming.com/index.php/site/reviews/P100/");
        expectWrite( "PruneTest", "range", "33");
    }
}
