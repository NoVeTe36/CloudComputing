import org.apache.spark.SparkConf;
import org.apache.spark.api.java.JavaPairRDD;
import org.apache.spark.api.java.JavaRDD;
import org.apache.spark.api.java.JavaSparkContext;
import scala.Tuple2;

import java.util.Arrays;

public class WordCount {
    public static void main(String[] args) {
        if (args.length < 2) {
            System.err.println("Usage: WordCount <input-file> <output-file>");
            System.exit(1);
        }

        String inputFile = args[0];
        String outputFile = args[1];

        SparkConf conf = new SparkConf().setAppName("WordCountBenchmark");
        JavaSparkContext sc = new JavaSparkContext(conf);

        long startTime = System.currentTimeMillis();

        JavaRDD<String> textFile = sc.textFile(inputFile);
        JavaPairRDD<String, Integer> counts = textFile
                .flatMap(s -> Arrays.asList(s.split("[^a-zA-Z]+")).iterator())
                .mapToPair(word -> new Tuple2<>(word.toLowerCase(), 1))
                .reduceByKey(Integer::sum);

        counts.saveAsTextFile(outputFile);
        
        long endTime = System.currentTimeMillis();
        System.out.println("========================================");
        System.out.println("Job completed for input: " + inputFile);
        System.out.println("Total execution time: " + (endTime - startTime) + " ms");
        System.out.println("========================================");

        sc.stop();
    }
}
