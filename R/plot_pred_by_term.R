#' Spatially plot predictions per model term
#'
#' Plot the effect of each smooth in the model spatially. For each term in the
#' model, plot its effect in space. Plots are made on the same scale, so that
#' the relative influence of each smooth can be seen.
#'
#' @param dsm.obj fitted [`dsm`][dsm] object
#' @param data data to use to plot (often the same as the prediction grid), data
#' should also include `width` and `height` columns for plotting
#' @param location.cov which covariates to plot by (usually 2, spatial
#' covariates, by default `c("x", "y")`
#' @param location.cov deprecated, use `location.cov`
#' @return a `ggplot2` plot
#' @export
#' @author David L Miller (idea taken from `inlabru`)
#' @importFrom ggplot2 ggplot geom_tile facet_wrap
#' @examples
#' \dontrun{
#' library(Distance)
#' library(dsm)
#'
#' # load the Gulf of Mexico dolphin data and fit a model
#' data(mexdolphins)
#' hr.model <- ds(distdata, truncation=6000,
#'                key = "hr", adjustment = NULL)
#' mod1 <- dsm(count~s(x,y) + s(depth), hr.model, segdata, obsdata)
#'
#' preddata$width <- preddata$height <- sqrt(preddata$area)
#'
#' # make the plot
#' plot_pred_by_term(mod1, preddata, c("x","y"))
#'
#' # better plot would be
#' # library(viridis)
#' # plot_pred_by_term(mod1, preddata, c("x","y")) + scale_fill_viridis()
#' }
plot_pred_by_term <- function(dsm.obj, data, location.cov=c("x", "y")){

  # warn on using deprecated args
  this_call <- match.call(expand.dots = FALSE)
  if("location_cov" %in% names(this_call)){
    stop("Argument: location_cov is deprecated, check documentation.")
  }

  # don't need offset
  data$off.set <- 0

  # make predictions per term
  preds <- predict(dsm.obj, data, type="terms")

  # make some data to plot
  plot_data <- c()
  # bind x,y,cov,covlabel for each cov
  for(col in colnames(preds)){
    plot_data <- rbind(plot_data,
                       cbind.data.frame(data, value=preds[, col], term=col))
  }


  # make a plot
  p <- ggplot(plot_data) +
    geom_tile(aes_string(x=location.cov[1], y=location.cov[2], fill="value")) +
    facet_wrap(~term)

  return(p)

}
