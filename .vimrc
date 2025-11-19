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


sealed class Animal {
    abstract val type: String
}

data class Dog(
    override val type: String = "dog",
    val name: String
) : Animal()

data class Cat(
    override val type: String = "cat",
    val name: String
) : Animal()

class AnimalDeserializer : JsonDeserializer<Animal> {
    override fun deserialize(
        json: JsonElement,
        typeOfT: Type,
        context: JsonDeserializationContext
    ): Animal {
        val obj = json.asJsonObject
        val type = obj["type"].asString

        return when (type) {
            "dog" -> context.deserialize(obj, Dog::class.java)
            "cat" -> context.deserialize(obj, Cat::class.java)
            else -> throw JsonParseException("Unknown type: $type")
        }
    }
}

val gson = GsonBuilder()
    .registerTypeAdapter(Animal::class.java, AnimalDeserializer())
    .create()

val json = """{"type":"dog","name":"Pochi"}"""
val animal: Animal = gson.fromJson(json, Animal::class.java)
// 中身は Dog(name=Pochi)

-----
plugins {
    id("com.android.application")
    kotlin("android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:<最新版>")
}

@Serializable
sealed class Animal {
    @Serializable
    @SerialName("dog")
    data class Dog(val name: String) : Animal()

    @Serializable
    @SerialName("cat")
    data class Cat(val name: String) : Animal()
}


@Serializable
sealed class ScreenState {
    @Serializable
    data class Loading(val message: String) : ScreenState()

    @Serializable
    data class Success(val user: User) : ScreenState()

    @Serializable
    data class Error(val code: Int, val detail: String) : ScreenState()
}

import kotlinx.serialization.json.Json

object JsonConfig {
    val json = Json {
        ignoreUnknownKeys = true   // 余計なフィールドが来ても無視
        encodeDefaults = true      // デフォルト値も出力
        // classDiscriminator = "type"  // sealed class の識別子名を変えたい場合
    }
}

// 遷移元
val json = JsonConfig.json.encodeToString(user)
val encoded = URLEncoder.encode(json, Charsets.UTF_8.name())
navController.navigate("detail/$encoded")

/ 遷移元
val state: ScreenState = ScreenState.Success(user)
val json = JsonConfig.json.encodeToString(state)
val encoded = URLEncoder.encode(json, Charsets.UTF_8.name())
navController.navigate("next/$encoded")


// グラフ定義
composable(
    route = "detail/{userJson}",
    arguments = listOf(
        navArgument("userJson") { type = NavType.StringType }
    )
) { backStackEntry ->
    val encoded = backStackEntry.arguments?.getString("userJson")!!
    val json = URLDecoder.decode(encoded, Charsets.UTF_8.name())
    val user = JsonConfig.json.decodeFromString<User>(json)
    DetailScreen(user)
}

val encoded = backStackEntry.arguments?.getString("stateJson")!!
val json = URLDecoder.decode(encoded, Charsets.UTF_8.name())
val state = JsonConfig.json.decodeFromString<ScreenState>(json)
