" 行番号を表示する
set number
" 検索結果をハイライトする
set hlsearch
" vimで開いているファイル名を表示する
set laststatus=2
" タブを表示するときの幅
set tabstop=4
" タブを挿入するときの幅
set shiftwidth=4 

" インサートモードのESCをjjにバインド
inoremap <silent> jj <ESC>


import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.scan

override fun observeMapMode(): Flow<GprsResponse<MapMode>> =
    combine(
        dataSource.observeMapTheme(),
        dataSource.observeOrientation(),
    ) { themeRes, orientationRes ->

        // DataSourceレベルのErrorはそのまま伝播（本当にエラー）
        if (themeRes.response != GprsResponse.Result.Success ||
            orientationRes.response != GprsResponse.Result.Success
        ) {
            return@combine Candidate.SourceError
        }

        val theme = themeRes.data ?: return@combine Candidate.SourceError
        val orientation = orientationRes.data ?: return@combine Candidate.SourceError

        val mode = themeAndOrientationToMapModeOrNull(theme, orientation)
        if (mode == null) Candidate.InvalidCombination else Candidate.Valid(mode)
    }
        // ★ここで「途中状態」を吸収
        .scan<GprsResponse<MapMode>?>(initial = null) { lastEmitted, candidate ->
            when (candidate) {
                is Candidate.Valid ->
                    GprsResponse(GprsResponse.Result.Success, candidate.mode)

                Candidate.SourceError ->
                    GprsResponse(GprsResponse.Result.Error, null)

                Candidate.InvalidCombination -> {
                    // 一時的な不整合は「前回の成功値があれば維持」
                    if (lastEmitted?.response == GprsResponse.Result.Success) {
                        lastEmitted
                    } else {
                        // 初回など、保持できる成功値がない場合だけError
                        GprsResponse(GprsResponse.Result.Error, null)
                    }
                }
            }
        }
        .distinctUntilChanged()
        // scanでnullableにしてるので最後に non-null に絞る
        .let { flow ->
            kotlinx.coroutines.flow.filterNotNull(flow)
        }

private sealed interface Candidate {
    data class Valid(val mode: MapMode) : Candidate
    data object InvalidCombination : Candidate
    data object SourceError : Candidate
}

private fun themeAndOrientationToMapModeOrNull(
    theme: Theme,
    orientation: Orientation
): MapMode? =
    when (theme) {
        Theme.NORMAL -> when (orientation) {
            Orientation.TWE_D,
            Orientation.NORTH_UP ->
                MapMode.MODE_TWE_D

            Orientation.THERE_D ->
                MapMode.MODE_THERE_D

            else ->
                null   // ★ 不正
        }

        Theme.HYBRID -> when (orientation) {
            Orientation.TWE_D,
            Orientation.NORTH_UP ->
                MapMode.MODE_SATELLITE

            else ->
                null   // ★ 不正
        }

        else ->
            null       // ★ 不正
    }

private fun MapMode.toThemeAndOrientation(): Pair<Theme, Orientation> =
    when (this) {
        MapMode.MODE_TWE_D -> Theme.NORMAL to Orientation.TWE_D
        MapMode.MODE_THERE_D -> Theme.NORMAL to Orientation.THERE_D
        MapMode.MODE_SATELLITE -> Theme.HYBRID to Orientation.TWE_D
    }


import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.withContext

class MapSettingsRepositoryImpl(
    private val dataSource: DataSource,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : MapSettingsRepository {

    override suspend fun setMapMode(mode: MapMode): UpdateResult =
        withContext(ioDispatcher) {
            // 1) 現在値をスナップショット（rollback用）
            val prev = runCatching { currentThemeAndOrientationOnce() }
                .getOrElse { e -> return@withContext UpdateResult.Failed("failed to get current state: ${e.message}") }

            val (targetTheme, targetOrientation) = mode.toThemeAndOrientation()

            // 2) Theme更新
            val themeRes = runCatching { dataSource.updateMapTheme(targetTheme) }
                .getOrElse { e -> return@withContext UpdateResult.Failed("updateMapTheme threw: ${e.message}") }

            if (themeRes.response != GprsResponse.Result.Success) {
                return@withContext UpdateResult.Failed("updateMapTheme error. mode=$mode")
            }

            // 3) Orientation更新
            val orientationRes = runCatching { dataSource.updateMapOrientation(targetOrientation) }
                .getOrElse { e ->
                    // 例外の場合も rollback
                    val rb = rollbackTo(prev)
                    return@withContext UpdateResult.Failed(
                        buildString {
                            append("updateMapOrientation threw: ${e.message}. mode=$mode")
                            if (rb != null) append(". rollback=$rb")
                        }
                    )
                }

            if (orientationRes.response != GprsResponse.Result.Success) {
                val rb = rollbackTo(prev)
                return@withContext UpdateResult.Failed(
                    buildString {
                        append("updateMapOrientation error. mode=$mode")
                        if (rb != null) append(". rollback=$rb")
                    }
                )
            }

            UpdateResult.Success
        }

    override fun observeMapMode(): Flow<GprsResponse<MapMode>> {
        // ここは前回の実装をそのまま利用でOK（必要なら貼り直します）
        TODO("your observeMapMode implementation")
    }

    /**
     * rollback用に「現時点の Theme/Orientation」を1回だけ取得する。
     * - 両方 Success かつ data != null の組を待つ
     */
    private suspend fun currentThemeAndOrientationOnce(): Pair<Theme, Orientation> =
        combine(
            dataSource.observeMapTheme(),
            dataSource.observeOrientation(),
        ) { themeRes, orientationRes ->
            themeRes to orientationRes
        }
            .filter { (t, o) ->
                t.response == GprsResponse.Result.Success &&
                    o.response == GprsResponse.Result.Success &&
                    t.data != null &&
                    o.data != null
            }
            .first()
            .let { (t, o) -> t.data!! to o.data!! }

    /**
     * スナップショットへ戻す（best-effort）
     * 戻し結果を文字列で返す。完全成功なら null。
     */
    private fun rollbackTo(prev: Pair<Theme, Orientation>): String? {
        val (prevTheme, prevOrientation) = prev

        // できるだけ「状態一貫」を戻すため両方実行（順序は好みだが、ここでは Theme→Orientation）
        val themeRb = runCatching { dataSource.updateMapTheme(prevTheme) }.getOrNull()
        val orientRb = runCatching { dataSource.updateMapOrientation(prevOrientation) }.getOrNull()

        val themeOk = themeRb?.response == GprsResponse.Result.Success
        val orientOk = orientRb?.response == GprsResponse.Result.Success

        return if (themeOk && orientOk) {
            null
        } else {
            "theme=${themeRb?.response ?: "threw"}, orientation=${orientRb?.response ?: "threw"}"
        }
    }
}
