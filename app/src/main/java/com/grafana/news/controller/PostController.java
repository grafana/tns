package com.grafana.news.controller;

import java.util.List;
import java.util.Map;

import javax.validation.Valid;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.grafana.news.exception.ResourceNotFoundException;
import com.grafana.news.model.Post;
import com.grafana.news.repository.PostRepository;

@RestController
@RequestMapping("/")
public class PostController {
	@Autowired
	PostRepository postRepository;

	@GetMapping("/")
	public List<Post> getPosts() {
        return postRepository.findAll();
	}

	@PutMapping("/post")
	public Post createPost(@Valid @RequestBody Post post) {
        return postRepository.save(post);
	}

	@PostMapping("/vote")
	public ResponseEntity<?>  upvote(@PathVariable(value = "id") Long postId) {
		Post post = postRepository.findById(postId)
				.orElseThrow(() -> new ResourceNotFoundException("Post", "id", postId));
        post.upvote();
        postRepository.save(post);
        return ResponseEntity.ok().build();
	}
}
