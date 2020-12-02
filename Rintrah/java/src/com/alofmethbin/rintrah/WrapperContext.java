package com.alofmethbin.rintrah;

import com.alofmethbin.rintrah.rules.Rule;
import java.io.File;
import java.io.Reader;
import java.util.List;

/**
 * Context which delegates all calls
 */
public abstract class WrapperContext extends Context 
{
    // Constructor
    public WrapperContext(Context delegate) {
        this.delegate = delegate;
        this.source = delegate.source;
    }

    @Override
    public void addColumn(String name, String defval) throws Exception {
        delegate.addColumn(name, defval);
    }

    @Override
    public void addWriteListener(WriteListener listener) {
        delegate.addWriteListener(listener);
    }

    @Override
    public void copy(Context base) throws Exception {
        delegate.copy(base);
    }

    @Override
    public Context duplicate() throws Exception {
        Context copy = delegate.duplicate();
        copy.setParent(this);
        return copy;
    }

    @Override
    public void error(String message) {
        delegate.error(message);
    }

    @Override
    public void execute() {
        delegate.execute(this);
    }

    @Override
    public Reader fileReader(String path) throws Exception {
        return delegate.fileReader(path);
    }

    @Override
    public String get(String key) throws Exception {
        return delegate.get(key);
    }

    @Override
    public String getAttribute(String name) {
        return delegate.getAttribute(name);
    }

    @Override
    public Branch getBranch(String name) throws Exception {
        return delegate.getBranch(name);
    }

    @Override
    public File getCachedFile(String url) {
        return delegate.getCachedFile(url);
    }

    @Override
    public String getElement() {
        return delegate.getElement();
    }

    @Override
    public int getInt(String key) throws Exception {
        return delegate.getInt(key);
    }

    @Override
    public int getLimit() {
        return delegate.getLimit();
    }

    @Override
    public int getPosition() {
        return delegate.getPosition();
    }

    @Override
    public List<Rule> getRules() {
        return delegate.getRules();
    }

    @Override
    public String getText() {
        return delegate.getText();
    }

    @Override
    public boolean httpLoadNew() {
        return delegate.httpLoadNew();
    }
    
    @Override
    public boolean isDirectory(String path) {
        return delegate.isDirectory(path);
    }

    @Override
    public void log( String message)
    {
        delegate.log( message);
    }
    
    @Override
    public void prune() {
        delegate.prune();
    }

    @Override
    public void put(String key, String value) {
        delegate.put(key, value);
    }

    @Override
    public void put(String key, int value) {
        delegate.put(key, value);
    }

    @Override
    public void recordCacheFile(File cacheFile) {
        delegate.recordCacheFile(cacheFile);
    }

    @Override
    public void saveCache(String url,File cached) throws Exception {
        delegate.saveCache(url,cached);
    }

    @Override
    public String setMonitor(String key, String value) {
        return delegate.setMonitor(key, value);
    }

    @Override
    public void setPosition(int position) {
        delegate.setPosition(position);
    }

    @Override
    public void setRules(List<Rule> list) {
        delegate.setRules(list);
    }

    @Override
    public void write(String source, String[] args) throws Exception {
        delegate.write(source, args);
    }

    // Delegate
    private Context delegate;
}
