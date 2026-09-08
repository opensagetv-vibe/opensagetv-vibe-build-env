/*
 * Copyright 2026 OpenSageTV Vibe contributors.
 * Licensed under the Apache License, Version 2.0.
 */
package org.opensagetv.vibe.tmdb;

import java.io.IOException;
import java.lang.reflect.Field;
import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

/** Deterministic shared-service fixture for the real SageMC and XMLTV adapters. */
public final class CrossConsumerFixture implements TmdbMetadataService {
  private static final CrossConsumerFixture INSTANCE = new CrossConsumerFixture();
  private static Field registryService;

  private final AtomicInteger searches = new AtomicInteger();
  private final AtomicInteger resolutions = new AtomicInteger();
  private final AtomicInteger details = new AtomicInteger();
  private final AtomicInteger episodes = new AtomicInteger();

  private CrossConsumerFixture() {}

  public static void install() throws Exception {
    registryService = TmdbServiceRegistry.class.getDeclaredField("service");
    registryService.setAccessible(true);
    registryService.set(null, INSTANCE);
  }

  public static void remove() throws Exception {
    if (registryService != null) registryService.set(null, null);
  }

  public static int totalCalls() {
    return INSTANCE.searches.get() + INSTANCE.resolutions.get()
        + INSTANCE.details.get() + INSTANCE.episodes.get();
  }

  public List<TmdbSearchResult> search(MediaType type, String query, Integer year) {
    searches.incrementAndGet();
    return Collections.singletonList(new TmdbSearchResult(
        id(type), type, query, query, "Search description", "2026-01-02", "",
        Collections.singletonList("US")));
  }

  public LookupResult resolveExact(MediaType type, String title, Integer year) {
    resolutions.incrementAndGet();
    return new LookupResult(LookupResult.Status.MATCHED, Long.valueOf(id(type)), title, 1L, 2L);
  }

  public Optional<LookupResult> resolveExactCached(MediaType type, String title, Integer year) {
    return Optional.of(new LookupResult(
        LookupResult.Status.MATCHED, Long.valueOf(id(type)), title, 1L, 2L));
  }

  public Map<MetadataLookupRequest, LookupResult> resolveExactBatch(
      List<MetadataLookupRequest> requests) {
    Map<MetadataLookupRequest, LookupResult> result =
        new LinkedHashMap<MetadataLookupRequest, LookupResult>();
    for (MetadataLookupRequest request : requests) {
      result.put(request, resolveExact(request.getMediaType(), request.getTitle(), request.getYear()));
    }
    return result;
  }

  public String getDetailsJson(MediaType type, long tmdbId, String appendToResponse) {
    details.incrementAndGet();
    return "{\"id\":" + tmdbId + ",\"name\":\"Shared Programme\","
        + "\"title\":\"Shared Programme\",\"overview\":\"Shared description\","
        + "\"first_air_date\":\"2026-01-02\",\"release_date\":\"2026-01-02\","
        + "\"original_language\":\"en\",\"poster_path\":\"\","
        + "\"origin_country\":[\"US\"],"
        + "\"production_countries\":[{\"name\":\"United States\"}],"
        + "\"genres\":[{\"name\":\"Drama\"}],"
        + "\"credits\":{\"cast\":[],\"crew\":[]}}";
  }

  public Optional<String> getCachedDetailsJson(
      MediaType type, long tmdbId, String appendToResponse) {
    return Optional.of(getDetailsJson(type, tmdbId, appendToResponse));
  }

  public TmdbEpisode getEpisode(long seriesId, int seasonNumber, int episodeNumber) {
    episodes.incrementAndGet();
    return new TmdbEpisode(300L, seriesId, seasonNumber, episodeNumber,
        "Shared episode", "Shared episode description", "2026-01-02", "");
  }

  public Optional<TmdbEpisode> getCachedEpisode(
      long seriesId, int seasonNumber, int episodeNumber) {
    return Optional.of(getEpisode(seriesId, seasonNumber, episodeNumber));
  }

  public TmdbArtworkConfiguration getArtworkConfiguration() {
    return new TmdbArtworkConfiguration("", "", Collections.<String>emptyList(),
        Arrays.asList("w500"), Arrays.asList("h632"), Arrays.asList("w300"));
  }

  public Optional<TmdbArtworkConfiguration> getCachedArtworkConfiguration() {
    return Optional.of(getArtworkConfiguration());
  }

  public void close() throws IOException {}

  private static long id(MediaType type) {
    return type == MediaType.MOVIE ? 101L : type == MediaType.TV ? 202L : 303L;
  }
}
