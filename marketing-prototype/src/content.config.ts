import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

const blog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/blog" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    category: z.enum(["Field Guide", "App Guide", "Product Updates"]),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    readTime: z.string(),
    author: z.string().default("Gardening Mentor Team"),
    featured: z.boolean().default(false),
    image: z.string().optional(),
    imageAlt: z.string().default(""),
    videoUrl: z.string().optional(),
    videoPoster: z.string().optional(),
    videoTitle: z.string().optional(),
  }),
});

export const collections = { blog };
