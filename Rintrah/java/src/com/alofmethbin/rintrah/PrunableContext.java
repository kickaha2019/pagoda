package com.alofmethbin.rintrah;

/**
 * Context which delegates all calls apart from prune
 */
public abstract class PrunableContext extends WrapperContext 
{
    // Constructor
    public PrunableContext(Context delegate) {
        super( delegate);
    }

    @Override
    public abstract void prune();
}
