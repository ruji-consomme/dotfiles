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


---
implementation("com.google.code.gson:gson:2.10.1")
---
import com.google.gson.*
import java.lang.reflect.Type
import java.net.URLEncoder
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

sealed class Animal {
    data class Dog(val type: String = "dog", val name: String, val age: Int) : Animal()
    data class Cat(val type: String = "cat", val name: String, val color: String) : Animal()
}

fun main() {
    val gson = GsonBuilder()
        .registerTypeAdapter(Animal::class.java, AnimalDeserializer())
        .create()

    val dog = Animal.Dog(name = "inu", age = 4)
    val json = gson.toJson(dog)
    println("json dog = $json")

    val restoredDog: Animal = gson.fromJson(json, Animal::class.java)
    println("restored dog = $restoredDog")
}

class AnimalDeserializer : JsonDeserializer<Animal> {
    override fun deserialize(
        json: JsonElement,
        typeOfT: Type,
        context: JsonDeserializationContext
    ): Animal {
        val obj = json.asJsonObject
        val type = obj["type"].asString   // Dog/Cat の type フィールドで分岐

        return when (type) {
            "dog" -> context.deserialize(obj, Animal.Dog::class.java)
            "cat" -> context.deserialize(obj, Animal.Cat::class.java)
            else -> throw JsonParseException("Unknown type: $type")
        }
    }
}
---



---
plugins {
    kotlin("jvm") version "2.2.20"
    id("org.jetbrains.kotlin.plugin.serialization") version "1.9.0"
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    testImplementation(kotlin("test"))
}

---
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

// -----------------------------
// sealed class Animal にネストされた Dog / Cat
// Kotlin のクラスには type プロパティを持たせない
// → JSON 上の "type" はポリモーフィック判定用の仮想フィールド
// -----------------------------
@Serializable
sealed class Animal {

    @Serializable
    @SerialName("dog")
    data class Dog(
        val name: String,
        val age: Int
    ) : Animal()

    @Serializable
    @SerialName("cat")
    data class Cat(
        val name: String,
        val color: String
    ) : Animal()
}

//// Kotlinx Serialization 用 Json インスタンス
//// classDiscriminator = "type" にしているので
//// JSON は {"type":"dog", "name":..., "age":...} のようになる
//val json = Json {
//    prettyPrint = true
//    classDiscriminator = "type"
//}

// -----------------------------
// 動作確認 main
// -----------------------------
fun main() {

    val dogOriginal: Animal = Animal.Dog(
        name = "POCHI",
        age = 4
    )

    val json = Json
//    val json = Json {
//        ignoreUnknownKeys = true   // 余計なフィールドが来ても無視
//        encodeDefaults = true      // デフォルト値も出力
        // classDiscriminator = "type"  // sealed class の識別子名を変えたい場合
//    }
//    val json = Json {
//        prettyPrint = true
//        classDiscriminator = "type"
//    }

    val jsonText = json.encodeToString<Animal>(dogOriginal)
    println(jsonText)

    val restored: Animal = json.decodeFromString(jsonText)
    println(restored)
}
---
