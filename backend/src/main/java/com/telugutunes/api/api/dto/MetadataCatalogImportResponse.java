package com.telugutunes.api.api.dto;

public record MetadataCatalogImportResponse(
    int imported, int updated, long total, boolean bucketStored, String objectKey, String message) {}
