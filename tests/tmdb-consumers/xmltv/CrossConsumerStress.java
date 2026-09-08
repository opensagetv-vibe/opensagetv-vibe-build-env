/*
 * Copyright 2026 OpenSageTV Vibe contributors.
 * Licensed under the Apache License, Version 2.0.
 */
package xmltv;

import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedList;
import java.util.List;
import java.util.Properties;
import java.util.Vector;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.opensagetv.vibe.sagemc.tmdb.SageMcTmdb;
import org.opensagetv.vibe.sagemc.tmdb.TmdbObject;
import org.opensagetv.vibe.sagemc.tmdb.TmdbRole;
import org.opensagetv.vibe.tmdb.CrossConsumerFixture;

/** Longer simultaneous run through both real consumer adapters. */
public final class CrossConsumerStress {
  private static final int THREADS_PER_CONSUMER = 4;
  private static final int ITERATIONS = 500;

  private CrossConsumerStress() {}

  public static void main(String[] args) throws Exception {
    CrossConsumerFixture.install();
    ExecutorService executor = Executors.newFixedThreadPool(THREADS_PER_CONSUMER * 2);
    CountDownLatch start = new CountDownLatch(1);
    List<Future<Void>> futures = new ArrayList<Future<Void>>();
    try {
      for (int index = 0; index < THREADS_PER_CONSUMER; index++) {
        futures.add(executor.submit(sageMcTask(start)));
        futures.add(executor.submit(xmltvTask(start)));
      }
      start.countDown();
      for (Future<Void> future : futures) future.get(90, TimeUnit.SECONDS);
      int minimumCalls = THREADS_PER_CONSUMER * ITERATIONS * 5;
      if (CrossConsumerFixture.totalCalls() < minimumCalls) {
        throw new AssertionError("shared service call count below stress minimum");
      }
      System.out.println("PASS: simultaneous SageMC/XMLTV TMDB adapter stress; operations="
          + (THREADS_PER_CONSUMER * ITERATIONS * 2)
          + ", serviceCalls=" + CrossConsumerFixture.totalCalls());
    } finally {
      start.countDown();
      executor.shutdownNow();
      executor.awaitTermination(10, TimeUnit.SECONDS);
      CrossConsumerFixture.remove();
    }
  }

  private static Callable<Void> sageMcTask(final CountDownLatch start) {
    return new Callable<Void>() {
      public Void call() throws Exception {
        start.await();
        SageMcTmdb adapter = new SageMcTmdb("", "");
        for (int iteration = 0; iteration < ITERATIONS; iteration++) {
          Vector<TmdbRole> matches = adapter.searchTitle("Shared Programme");
          if (matches.size() != 2) throw new AssertionError("SageMC search result count");
          TmdbObject object = adapter.getDbObject(matches.get(0).getName());
          if (object == null || !adapter.getLastError().isEmpty()) {
            throw new AssertionError("SageMC details adapter failure: " + adapter.getLastError());
          }
        }
        return null;
      }
    };
  }

  private static Callable<Void> xmltvTask(final CountDownLatch start) {
    return new Callable<Void>() {
      public Void call() throws Exception {
        start.await();
        Properties properties = new Properties();
        properties.setProperty("xmltv.tmdb.enrich", "true");
        properties.setProperty("xmltv.tmdb.max_lookups_per_import", "1");
        for (int iteration = 0; iteration < ITERATIONS; iteration++) {
          TmdbEnricher adapter = TmdbEnricher.create(properties);
          Show show = new Show(new Date(1000L), new Date(2000L));
          show.title = "Shared Programme";
          show.season = 1;
          show.episode = 1;
          List<String> categories = new LinkedList<String>();
          adapter.enrichMissing(show, categories, "Series");
          if (show.descriptions.isEmpty()
              || !"Shared episode description".equals(show.descriptions.get(0))
              || categories.isEmpty()) {
            throw new AssertionError("XMLTV enrichment adapter failure");
          }
        }
        return null;
      }
    };
  }
}
