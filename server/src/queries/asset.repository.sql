-- NOTE: This file is auto generated by ./sql-generator

-- AssetRepository.updateAllExif
update "exif"
set
  "model" = $1
where
  "assetId" in ($2)

-- AssetRepository.getByDayOfYear
with
  "res" as (
    with
      "today" as (
        select
          make_date(year::int, $1::int, $2::int) as "date"
        from
          generate_series(
            (
              select
                date_part(
                  'year',
                  min(("localDateTime" at time zone 'UTC')::date)
                )::int
              from
                assets
            ),
            date_part('year', current_date)::int - 1
          ) as "year"
      )
    select
      "a".*,
      to_json("exif") as "exifInfo"
    from
      "today"
      inner join lateral (
        select
          "assets".*
        from
          "assets"
          inner join "asset_job_status" on "assets"."id" = "asset_job_status"."assetId"
        where
          "asset_job_status"."previewAt" is not null
          and (assets."localDateTime" at time zone 'UTC')::date = today.date
          and "assets"."ownerId" = any ($3::uuid[])
          and "assets"."visibility" = $4
          and exists (
            select
            from
              "asset_files"
            where
              "assetId" = "assets"."id"
              and "asset_files"."type" = $5
          )
          and "assets"."deletedAt" is null
        order by
          (assets."localDateTime" at time zone 'UTC')::date desc
        limit
          $6
      ) as "a" on true
      inner join "exif" on "a"."id" = "exif"."assetId"
  )
select
  date_part(
    'year',
    ("localDateTime" at time zone 'UTC')::date
  )::int as "year",
  json_agg("res") as "assets"
from
  "res"
group by
  ("localDateTime" at time zone 'UTC')::date
order by
  ("localDateTime" at time zone 'UTC')::date desc

-- AssetRepository.getByIds
select
  "assets".*
from
  "assets"
where
  "assets"."id" = any ($1::uuid[])

-- AssetRepository.getByIdsWithAllRelationsButStacks
select
  "assets".*,
  (
    select
      coalesce(json_agg(agg), '[]')
    from
      (
        select
          "asset_faces".*,
          "person" as "person"
        from
          "asset_faces"
          left join lateral (
            select
              "person".*
            from
              "person"
            where
              "asset_faces"."personId" = "person"."id"
          ) as "person" on true
        where
          "asset_faces"."assetId" = "assets"."id"
          and "asset_faces"."deletedAt" is null
      ) as agg
  ) as "faces",
  (
    select
      coalesce(json_agg(agg), '[]')
    from
      (
        select
          "tags"."id",
          "tags"."value",
          "tags"."createdAt",
          "tags"."updatedAt",
          "tags"."color",
          "tags"."parentId"
        from
          "tags"
          inner join "tag_asset" on "tags"."id" = "tag_asset"."tagsId"
        where
          "assets"."id" = "tag_asset"."assetsId"
      ) as agg
  ) as "tags",
  to_json("exif") as "exifInfo"
from
  "assets"
  left join "exif" on "assets"."id" = "exif"."assetId"
  left join "asset_stack" on "asset_stack"."id" = "assets"."stackId"
where
  "assets"."id" = any ($1::uuid[])

-- AssetRepository.deleteAll
delete from "assets"
where
  "ownerId" = $1

-- AssetRepository.getByLibraryIdAndOriginalPath
select
  "assets".*
from
  "assets"
where
  "libraryId" = $1::uuid
  and "originalPath" = $2
limit
  $3

-- AssetRepository.getAllByDeviceId
select
  "deviceAssetId"
from
  "assets"
where
  "ownerId" = $1::uuid
  and "deviceId" = $2
  and "visibility" != $3
  and "deletedAt" is null

-- AssetRepository.getLivePhotoCount
select
  count(*) as "count"
from
  "assets"
where
  "livePhotoVideoId" = $1::uuid

-- AssetRepository.getById
select
  "assets".*
from
  "assets"
where
  "assets"."id" = $1::uuid
limit
  $2

-- AssetRepository.updateAll
update "assets"
set
  "deviceId" = $1
where
  "id" = any ($2::uuid[])

-- AssetRepository.updateDuplicates
update "assets"
set
  "duplicateId" = $1
where
  (
    "duplicateId" = any ($2::uuid[])
    or "id" = any ($3::uuid[])
  )

-- AssetRepository.getByChecksum
select
  "assets".*
from
  "assets"
where
  "ownerId" = $1::uuid
  and "checksum" = $2
  and "libraryId" = $3::uuid
limit
  $4

-- AssetRepository.getByChecksums
select
  "id",
  "checksum",
  "deletedAt"
from
  "assets"
where
  "ownerId" = $1::uuid
  and "checksum" in ($2)

-- AssetRepository.getUploadAssetIdByChecksum
select
  "id"
from
  "assets"
where
  "ownerId" = $1::uuid
  and "checksum" = $2
  and "libraryId" is null
limit
  $3

-- AssetRepository.getTimeBuckets
with
  "assets" as (
    select
      date_trunc($1, "localDateTime" at time zone 'UTC') at time zone 'UTC' as "timeBucket"
    from
      "assets"
    where
      "assets"."deletedAt" is null
      and (
        "assets"."visibility" = $2
        or "assets"."visibility" = $3
      )
  )
select
  "timeBucket",
  count(*) as "count"
from
  "assets"
group by
  "timeBucket"
order by
  "timeBucket" desc

-- AssetRepository.getTimeBucket
select
  "assets".*,
  to_json("exif") as "exifInfo",
  to_json("stacked_assets") as "stack"
from
  "assets"
  left join "exif" on "assets"."id" = "exif"."assetId"
  left join "asset_stack" on "asset_stack"."id" = "assets"."stackId"
  left join lateral (
    select
      "asset_stack".*,
      count("stacked") as "assetCount"
    from
      "assets" as "stacked"
    where
      "stacked"."stackId" = "asset_stack"."id"
      and "stacked"."deletedAt" is null
      and "stacked"."visibility" != $1
    group by
      "asset_stack"."id"
  ) as "stacked_assets" on "asset_stack"."id" is not null
where
  (
    "asset_stack"."primaryAssetId" = "assets"."id"
    or "assets"."stackId" is null
  )
  and "assets"."deletedAt" is null
  and (
    "assets"."visibility" = $2
    or "assets"."visibility" = $3
  )
  and date_trunc($4, "localDateTime" at time zone 'UTC') at time zone 'UTC' = $5
order by
  "assets"."localDateTime" desc

-- AssetRepository.getDuplicates
with
  "duplicates" as (
    select
      "assets"."duplicateId",
      jsonb_agg("asset") as "assets"
    from
      "assets"
      left join lateral (
        select
          "assets".*,
          "exif" as "exifInfo"
        from
          "exif"
        where
          "exif"."assetId" = "assets"."id"
      ) as "asset" on true
    where
      "assets"."ownerId" = $1::uuid
      and "assets"."duplicateId" is not null
      and "assets"."deletedAt" is null
      and "assets"."visibility" != $2
      and "assets"."stackId" is null
    group by
      "assets"."duplicateId"
  ),
  "unique" as (
    select
      "duplicateId"
    from
      "duplicates"
    where
      jsonb_array_length("assets") = $3
  ),
  "removed_unique" as (
    update "assets"
    set
      "duplicateId" = $4
    from
      "unique"
    where
      "assets"."duplicateId" = "unique"."duplicateId"
  )
select
  *
from
  "duplicates"
where
  not exists (
    select
    from
      "unique"
    where
      "unique"."duplicateId" = "duplicates"."duplicateId"
  )

-- AssetRepository.getAssetIdByCity
with
  "cities" as (
    select
      "city"
    from
      "exif"
    where
      "city" is not null
    group by
      "city"
    having
      count("assetId") >= $1
  )
select distinct
  on ("exif"."city") "assetId" as "data",
  "exif"."city" as "value"
from
  "assets"
  inner join "exif" on "assets"."id" = "exif"."assetId"
  inner join "cities" on "exif"."city" = "cities"."city"
where
  "ownerId" = $2::uuid
  and "visibility" = $3
  and "type" = $4
  and "deletedAt" is null
limit
  $5

-- AssetRepository.getAllForUserFullSync
select
  "assets".*,
  to_json("exif") as "exifInfo",
  to_json("stacked_assets") as "stack"
from
  "assets"
  left join "exif" on "assets"."id" = "exif"."assetId"
  left join "asset_stack" on "asset_stack"."id" = "assets"."stackId"
  left join lateral (
    select
      "asset_stack".*,
      count("stacked") as "assetCount"
    from
      "assets" as "stacked"
    where
      "stacked"."stackId" = "asset_stack"."id"
    group by
      "asset_stack"."id"
  ) as "stacked_assets" on "asset_stack"."id" is not null
where
  "assets"."ownerId" = $1::uuid
  and "assets"."visibility" != $2
  and "assets"."updatedAt" <= $3
  and "assets"."id" > $4
order by
  "assets"."id"
limit
  $5

-- AssetRepository.getChangedDeltaSync
select
  "assets".*,
  to_json("exif") as "exifInfo",
  to_json("stacked_assets") as "stack"
from
  "assets"
  left join "exif" on "assets"."id" = "exif"."assetId"
  left join "asset_stack" on "asset_stack"."id" = "assets"."stackId"
  left join lateral (
    select
      "asset_stack".*,
      count("stacked") as "assetCount"
    from
      "assets" as "stacked"
    where
      "stacked"."stackId" = "asset_stack"."id"
    group by
      "asset_stack"."id"
  ) as "stacked_assets" on "asset_stack"."id" is not null
where
  "assets"."ownerId" = any ($1::uuid[])
  and "assets"."visibility" != $2
  and "assets"."updatedAt" > $3
limit
  $4
